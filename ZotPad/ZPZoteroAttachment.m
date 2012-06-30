//
//  ZPZoteroAttachment.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//



#import "ZPCore.h"
#import "ZPDatabase.h"
#include "FileMD5Hash.h"


NSInteger const LINK_MODE_IMPORTED_FILE = 0;
NSInteger const LINK_MODE_IMPORTED_URL = 1;
NSInteger const LINK_MODE_LINKED_FILE = 2;
NSInteger const LINK_MODE_LINKED_URL = 3;

NSInteger const VERSION_SOURCE_ZOTERO =1;
NSInteger const VERSION_SOURCE_WEBDAV =2;
NSInteger const VERSION_SOURCE_DROPBOX =3;

@interface ZPZoteroAttachment(){
    NSString* _versionIdentifier_local;
}
- (NSString*) _fileSystemPathWithSuffix:(NSString*)suffix;
@end

@implementation ZPZoteroAttachment

@synthesize lastViewed, attachmentSize, existsOnZoteroServer, filename, url, versionSource, versionIdentifier_server, charset, md5;
//@synthesize versionIdentifier_local;

-(void) setVersionIdentifier_local:(NSString *)versionIdentifier_local{
    DDLogVerbose(@"Set local MD5 %@ for item %@",versionIdentifier_local, self.key);
    _versionIdentifier_local = versionIdentifier_local;
}
-(NSString*) versionIdentifier_local{
    return _versionIdentifier_local;
}

+(id) dataObjectWithDictionary:(NSDictionary *)fields{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:fields ];
    [dict setObject:@"attachment" forKey:@"itemType"];
    ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) [super dataObjectWithDictionary:dict];
    
    //Set some default values
    if(attachment.existsOnZoteroServer == nil){
        attachment.existsOnZoteroServer = [NSNumber numberWithBool:NO];   
    }

    return attachment;
}

- (NSNumber*) libraryID{
    //Child attachments
    if(super.libraryID==NULL) return [ZPZoteroItem dataObjectWithKey:self.parentItemKey].libraryID;
    //Standalone attachments
    else return super.libraryID;
}

// An alias for setParentCollectionKey
- (void) setParentKey:(NSString*)key{
    [self setParentItemKey:key];    
}

- (void) setParentItemKey:(NSString*)key{
    _parentItemKey = key; 
}
- (NSString*) parentItemKey{
    if(_parentItemKey == NULL){
        return self.key;
    }
    else{
        return _parentItemKey;
    }
}

+(ZPZoteroAttachment*) dataObjectForAttachedFile:(NSString*) filename{

    //Strip the file ending
    filename = [[filename lastPathComponent] stringByDeletingPathExtension];
    
    //Get the key from the filename
    NSString* key =[[filename componentsSeparatedByString: @"_"] lastObject];
    
    //If this is a locally modified file or a version, strip the trailing - from the key
    key = [key substringToIndex:8];
 
    ZPZoteroAttachment* attachment= (ZPZoteroAttachment*) [self dataObjectWithKey:key];
    if(attachment.filename == NULL) attachment = NULL;

    return attachment;
    
}

- (NSString*) fileSystemPath{
    NSString* modified =[self fileSystemPath_modified];
    if([[NSFileManager defaultManager] fileExistsAtPath:modified]) return modified;
    else return [self fileSystemPath_original];
}

- (NSString*) _fileSystemPathWithSuffix:(NSString*)suffix{
    
    NSString* path;
    //Imported URLs are stored as ZIP files
    
    if([self.linkMode intValue] == LINK_MODE_IMPORTED_URL && [self.contentType isEqualToString:@"text/html"]){
        path = [[self filename] stringByAppendingFormat:@"_%@%@.zip",self.key,suffix];
    }
    else{
        NSRange lastPeriod = [[self filename] rangeOfString:@"." options:NSBackwardsSearch];
        
        
        if(lastPeriod.location == NSNotFound) path = [[self filename] stringByAppendingFormat:@"_%@%@",self.key,suffix];
        else path = [[self filename] stringByReplacingCharactersInRange:lastPeriod
                                                             withString:[NSString stringWithFormat:@"_%@%@.",self.key,suffix]];
    }
    return  [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:path];
    
}

- (NSString*) fileSystemPath_modified{
    return [self _fileSystemPathWithSuffix:@"-"];
}

- (NSString*) fileSystemPath_original{
    return [self _fileSystemPathWithSuffix:@""];
}

-(void) setContentType:(NSString *)contentType{
    if(contentType != (NSObject*) [NSNull null]){
        _contentType = contentType;
    }
}
-(NSString*) contentType{
    return  _contentType;
}
-(void) setLinkMode:(NSNumber *)linkMode{
    _linkMode = linkMode;
    //set text/HTML as the default type for links
    if([_linkMode intValue]==LINK_MODE_LINKED_URL && _contentType == NULL){
        _contentType = @"text/html";
    }
}
-(NSNumber*)linkMode{
    return _linkMode;
}

- (NSArray*) creators{
    return [NSArray array];
}
- (NSDictionary*) fields{
    return [NSDictionary dictionary];
}

-(NSString*) itemType{
    return @"attachment";
}

- (NSArray*) attachments{
    return [NSArray arrayWithObject:self];
}

- (void) setAttachments:(NSArray *)attachments{
}

//If an attachment is updated, delete the old attachment file
- (void) setServerTimestamp:(NSString*)timestamp{
    [super setServerTimestamp:timestamp];
    if(![self.serverTimestamp isEqual:self.cacheTimestamp] && [self fileExists]){
        //If the file MD5 does not match the server MD5, delete it.
        NSString* fileMD5 = [self md5ForFileAtPath:self.fileSystemPath_original];
        if(! [self.md5 isEqualToString:fileMD5]){
            [[NSFileManager defaultManager] removeItemAtPath: [self fileSystemPath_original] error:NULL];   
        }
    }
    
}

-(BOOL) fileExists{
    //If there is no known filename for the item, then the item cannot exists in cache
    if(self.filename == nil || self.filename == (NSObject*)[NSNull null]){
        return false;
    }
    NSString* fsPath = [self fileSystemPath];
    if(fsPath == NULL)
        return false; 
    else
        return ([[NSFileManager defaultManager] fileExistsAtPath:fsPath]);
}

#pragma mark - QLPreviewItem protocol

-(NSURL*) previewItemURL{
    
    //Return path to uncompressed files.
    //TODO: Encapsulate as a method
    if([self.linkMode intValue] == LINK_MODE_IMPORTED_URL && [self.contentType isEqualToString:@"text/html"]){
        NSString* tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:self.key];
        
        return [NSURL fileURLWithPath:[tempDir stringByAppendingPathComponent:self.filename]];
    }
    else return [NSURL fileURLWithPath:self.fileSystemPath];
}

-(NSString*) previewItemTitle{
    return self.filename;
}


//Helper function for MD5 sums

-(NSString*) md5ForFileAtPath:(NSString*)path{
    
    if(! [[NSFileManager defaultManager] fileExistsAtPath:path]){
        [NSException raise:@"File not found" format:@"Attempted to calculate MD5 sum for a non-existing file at %@",path];
    }
    
    //TODO: Make sure that this does not leak memory
    
    NSString* md5 = (__bridge_transfer NSString*) FileMD5HashCreateWithPath((__bridge CFStringRef) path, FileHashDefaultChunkSizeForReadingData);
    return md5;
}

@end

