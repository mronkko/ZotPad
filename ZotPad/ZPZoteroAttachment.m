//
//  ZPZoteroAttachment.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//



#import "ZPCore.h"
#import "ZPDatabase.h"
#import "FileMD5Hash.h"
#import "QSStrings.h"
#import "ZPCacheController.h"

NSInteger const LINK_MODE_IMPORTED_FILE = 0;
NSInteger const LINK_MODE_IMPORTED_URL = 1;
NSInteger const LINK_MODE_LINKED_FILE = 2;
NSInteger const LINK_MODE_LINKED_URL = 3;

NSInteger const VERSION_SOURCE_ZOTERO =1;
NSInteger const VERSION_SOURCE_WEBDAV =2;
NSInteger const VERSION_SOURCE_DROPBOX =3;

@interface ZPZoteroAttachment(){
    NSString* _md5;
}
- (NSString*) _fileSystemPathWithSuffix:(NSString*)suffix;

@end

@implementation ZPZoteroAttachment

@synthesize lastViewed, attachmentSize, existsOnZoteroServer, filename, url, versionSource,  charset;
@synthesize versionIdentifier_server;
@synthesize versionIdentifier_local;

//@synthesize versionIdentifier_local;


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
    
    if(self.filename == NULL || self.filename == [NSNull null]) return NULL;
    
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
    if(![self.serverTimestamp isEqual:self.cacheTimestamp] && [self fileExists_original]){
        //If the file MD5 does not match the server MD5, delete it.
        NSString* fileMD5 = [ZPZoteroAttachment md5ForFileAtPath:self.fileSystemPath_original];
        if(! [self.md5 isEqualToString:fileMD5]){
            [[NSFileManager defaultManager] removeItemAtPath: [self fileSystemPath_original] error:NULL];   
        }
    }
    
}

-(NSString*) filenameZoteroBase64Encoded{
    //This is a workaround to fix a double encoding bug in Zotero
    
    NSData* UTF8Data = [self.filename dataUsingEncoding:NSUTF8StringEncoding];
    NSString* asciiString = [[NSString alloc] initWithData:UTF8Data encoding:NSASCIIStringEncoding];
    NSData* doubleEncodedUTF8Data = [asciiString dataUsingEncoding:NSUTF8StringEncoding];
    
    return [[QSStrings encodeBase64WithData:doubleEncodedUTF8Data] stringByAppendingString:@"\%ZB64"];
}

#pragma mark - File operations

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

-(BOOL) fileExists_original{
    //If there is no known filename for the item, then the item cannot exists in cache
    if(self.filename == nil || self.filename == (NSObject*)[NSNull null]){
        return false;
    }
    NSString* fsPath = [self fileSystemPath_original];
    if(fsPath == NULL)
        return false; 
    else
        return ([[NSFileManager defaultManager] fileExistsAtPath:fsPath]);
}

-(BOOL) fileExists_modified{
    //If there is no known filename for the item, then the item cannot exists in cache
    if(self.filename == nil || self.filename == (NSObject*)[NSNull null]){
        return false;
    }
    NSString* fsPath = [self fileSystemPath_modified];
    if(fsPath == NULL)
        return false; 
    else
        return ([[NSFileManager defaultManager] fileExistsAtPath:fsPath]);
}

-(void) setMd5:(NSString *)md5{
    if(md5!= NULL && md5 != [NSNull null]){
        if(_md5!= NULL && _md5 != [NSNull null] && ! [_md5 isEqualToString:md5]){
            //The file has changed on the server, so we will queue a download for it
            [[ZPCacheController instance] addAttachmentToDowloadQueue:self];
        }
    }
    _md5 = md5;
}
-(NSString*) md5{
    return _md5;
}
//The reason for purging a file will be logged 

-(void) purge:(NSString*) reason{
    [self purge_modified:reason];
    [self purge_original:reason];
}

-(void) purge_original:(NSString*) reason{
    if([self fileExists_original]){
        NSDictionary* fileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:self.fileSystemPath_original traverseLink:NO];
        [[NSFileManager defaultManager] removeItemAtPath:self.fileSystemPath_original error:NULL];
        [[ZPDataLayer instance] notifyAttachmentDeleted:self fileAttributes:fileAttributes];
        DDLogWarn(@"File %@ (version from server) was deleted: %@",self.filename,reason);
    }
}
-(void) purge_modified:(NSString*) reason{
    if([self fileExists_modified]){
        NSDictionary* fileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:self.fileSystemPath_modified traverseLink:NO];
        [[NSFileManager defaultManager] removeItemAtPath:self.fileSystemPath_modified error:NULL];
        [[ZPDataLayer instance] notifyAttachmentDeleted:self fileAttributes:fileAttributes];
        DDLogWarn(@"File %@ (locally modified) was deleted: %@",self.filename,reason);
    }
}

//TODO: These should update the cache size. This is a minor issue, implement after implementing NSNotification

-(void) moveFileFromPathAsNewOriginalFile:(NSString*) path{
    NSAssert2([[NSFileManager defaultManager] fileExistsAtPath:path],@"Attempted to associate non-existing file from %@ with attachment %@", path,self.key);
    [[NSFileManager defaultManager] removeItemAtPath:self.fileSystemPath_original error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:path toPath:self.fileSystemPath_original error:NULL];

    //Set this file as not cached
    const char* filePath = [self.fileSystemPath_original fileSystemRepresentation];
    const char* attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
    setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);

}

-(void) moveFileFromPathAsNewModifiedFile:(NSString*) path{
    NSAssert2([[NSFileManager defaultManager] fileExistsAtPath:path],@"Attempted to associate non-existing file from %@ with attachment %@", path,self.key);
    [[NSFileManager defaultManager] removeItemAtPath:self.fileSystemPath_modified error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:path toPath:self.fileSystemPath_modified error:NULL];

    //Set this file as not cached
    const char* filePath = [self.fileSystemPath_modified fileSystemRepresentation];
    const char* attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
    setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
}

-(void) moveModifiedFileAsOriginalFile{
    [self moveFileFromPathAsNewOriginalFile:self.fileSystemPath_modified];
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

+(NSString*) md5ForFileAtPath:(NSString*)path{
    
    if(! [[NSFileManager defaultManager] fileExistsAtPath:path]){
        [NSException raise:@"File not found" format:@"Attempted to calculate MD5 sum for a non-existing file at %@",path];
    }
    
    //TODO: Make sure that this does not leak memory
    
    NSString* md5 = (__bridge_transfer NSString*) FileMD5HashCreateWithPath((__bridge CFStringRef) path, FileHashDefaultChunkSizeForReadingData);
    return md5;
}

+(NSString*) zoteroBase64Encode:(NSString*)filename{
    return [[QSStrings encodeBase64WithString:filename] stringByAppendingString:@"%ZB64"];
}

+(NSString*) zoteroBase64Decode:(NSString*)filename{
    NSString* toBeDecoded = [filename substringToIndex:[filename length] - 5];
    NSData* decodedData = [QSStrings decodeBase64WithString:toBeDecoded] ;
    NSString* decodedFilename = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
    return decodedFilename;
}


-(void) logFileRevisions{
    DDLogInfo(@"MD5: %@ Server: %@ Local %@: Filename %@",self.md5,self.versionIdentifier_server,self.versionIdentifier_local,self.filename);
}

@end

