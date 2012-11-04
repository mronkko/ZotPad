//
//  ZPZoteroAttachment.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//



#import "ZPCore.h"

#import "FileMD5Hash.h"
#import "ZPCacheController.h"
#import "NSString+Base64.h"
#include <sys/xattr.h>


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

static NSCache* _objectCache = NULL;
static NSString* _documentsDirectory = NULL;

@synthesize lastViewed, attachmentSize, existsOnZoteroServer, filename, url, versionSource,  charset, note;
@synthesize versionIdentifier_server;
@synthesize versionIdentifier_local;
@synthesize contentType;

+(void)initialize{
    _objectCache =  [[NSCache alloc] init];
    _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}


+(ZPZoteroAttachment*) attachmentWithDictionary:(NSDictionary *)fields{
    
    NSString* key = [fields objectForKey:ZPKEY_ITEM_KEY];

    if(key == NULL || [key isEqual:@""])
        [NSException raise:@"Key is empty" format:@"ZPZoteroAttachment cannot be instantiated with empty key"];

    ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) [_objectCache objectForKey:key];
                                                            
    if(attachment == NULL){
        attachment = [[ZPZoteroAttachment alloc] init];
    }
    
    [attachment configureWithDictionary:fields];
    
    return attachment;
}

+(ZPZoteroAttachment*) attachmentWithKey:(NSString *)key{

    if(key == NULL || [key isEqual:@""])
        [NSException raise:@"Key is empty" format:@"ZPZoteroAttachment cannot be instantiated with empty key"];
    
    ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) [_objectCache objectForKey:key];
    
    if(attachment == NULL){
        attachment = [ZPZoteroAttachment attachmentWithDictionary:[ZPDatabase attributesForAttachmentWithKey:key]];
    }
    
    return attachment;
    
}


-(void) setItemKey:(NSString *)itemKey{
    [super setKey:itemKey];
}
-(NSString*)itemKey{
    return [super key];
}

- (NSInteger) libraryID{
    //Child attachments
    if(super.libraryID==LIBRARY_ID_NOT_SET){
        if(self.parentKey != NULL){
            return [ZPZoteroItem itemWithKey:self.parentKey].libraryID;
        }
        else {
            [NSException raise:@"Internal consistency error" format:@"Standalone items must have library IDs. Standalone attachment with key %@ had a null library ID",self.key];
            return LIBRARY_ID_NOT_SET;
        }
    }
    else{
        //Standalone attachments
        return super.libraryID;
    }
}

+(ZPZoteroAttachment*) dataObjectForAttachedFile:(NSString*) filename{

    //Strip the file ending
    NSString* parsedFilename = [[filename lastPathComponent] stringByDeletingPathExtension];
    
    //Get the key from the filename
    NSString* key =[[parsedFilename componentsSeparatedByString: @"_"] lastObject];
    
    //TODO: 
    if(key == NULL || [key isEqualToString:@""]){
        DDLogError(@"While scanning for files to upload, parsing filename %@ resulted in empty key",filename);
        return NULL;
    }
    
    ZPZoteroAttachment* attachment;
    //If this is a locally modified file or a version, strip the trailing - from the key
    if(key.length>8){
        NSString* newKey = [key substringToIndex:8];
        attachment = [self attachmentWithKey:newKey];
    }
    else{
        attachment = [self attachmentWithKey:key];
    }
    if(attachment.filename == NULL) attachment = NULL;

    return attachment;
    
}

- (NSString*) fileSystemPath{
    NSString* modified =[self fileSystemPath_modified];
    if([[NSFileManager defaultManager] fileExistsAtPath:modified]) return modified;
    else return [self fileSystemPath_original];
}

- (NSString*) _fileSystemPathWithSuffix:(NSString*)suffix{
    
    if(self.filename == NULL ) return NULL;
    
    NSString* path;
    //Imported URLs are stored as ZIP files
    
    if(_linkMode == LINK_MODE_IMPORTED_URL && ([self.contentType isEqualToString:@"text/html"]
                                                              || [self.contentType isEqualToString:@"application/xhtml+xml"])){
        path = [[self filename] stringByAppendingFormat:@"_%@%@.zip",self.key,suffix];
    }
    else{
        NSRange lastPeriod = [[self filename] rangeOfString:@"." options:NSBackwardsSearch];
        
        
        if(lastPeriod.location == NSNotFound){
            path = [[self filename] stringByAppendingFormat:@"_%@%@",self.key,suffix];
        }
        else{
            path = [[self filename] stringByReplacingCharactersInRange:lastPeriod
                                                             withString:[NSString stringWithFormat:@"_%@%@.",self.key,suffix]];
        }
    }
    
    NSString* ret = [_documentsDirectory stringByAppendingPathComponent:path];
    
    return ret;
    
}

- (NSString*) fileSystemPath_modified{
    return [self _fileSystemPathWithSuffix:@"-"];
}

- (NSString*) fileSystemPath_original{
    return [self _fileSystemPathWithSuffix:@""];
}

-(void) setLinkMode:(NSInteger)linkMode{
    _linkMode = linkMode;
    //set text/HTML as the default type for links
    if(_linkMode ==LINK_MODE_LINKED_URL && self.contentType == NULL){
        self.contentType = @"text/html";
    }
}
-(NSInteger)linkMode{
    return _linkMode;
}

//If an attachment is updated, delete the old attachment file
- (void) setServerTimestamp:(NSString*)timestamp{
    [super setServerTimestamp:timestamp];
    if(![self.serverTimestamp isEqual:self.cacheTimestamp] && [self fileExists_original]){
        //If the file MD5 does not match the server MD5, delete it.
        NSString* fileMD5 = [ZPZoteroAttachment md5ForFileAtPath:self.fileSystemPath_original];
        if(self.md5 == NULL || ! [self.md5 isEqualToString:fileMD5]){
            [[NSFileManager defaultManager] removeItemAtPath: [self fileSystemPath_original] error:NULL];   
        }
    }
    
}

-(NSString*) filenameZoteroBase64Encoded{

    //This is a workaround to fix a double encoding bug in Zotero
    /*
    NSData* UTF8Data = [self.filename dataUsingEncoding:NSUTF8StringEncoding];
    NSString* asciiString = [[NSString alloc] initWithData:UTF8Data encoding:NSASCIIStringEncoding];
    NSData* doubleEncodedUTF8Data = [asciiString dataUsingEncoding:NSUTF8StringEncoding];
    
    return [[QSStrings encodeBase64WithData:doubleEncodedUTF8Data] stringByAppendingString:@"\%ZB64"];
     
     */

    return [ZPZoteroAttachment zoteroBase64Decode:filename];
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
    if(md5!= NULL){
        if(_md5!= NULL && ! [_md5 isEqualToString:md5]){
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
        NSDictionary* fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.fileSystemPath_original error:NULL];
        [[NSFileManager defaultManager] removeItemAtPath:self.fileSystemPath_original error:NULL];
        [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_DELETED object:self userInfo:fileAttributes];
        DDLogWarn(@"File %@ (version from server) was deleted: %@",self.filename,reason);
    }
}
-(void) purge_modified:(NSString*) reason{
    if([self fileExists_modified]){
        NSDictionary* fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.fileSystemPath_modified error:NULL];
        [[NSFileManager defaultManager] removeItemAtPath:self.fileSystemPath_modified error:NULL];
        [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_DELETED object:self userInfo:fileAttributes];
        DDLogWarn(@"File %@ (locally modified) was deleted: %@",self.filename,reason);
    }
}

//TODO: These should update the cache size. This is a minor issue, implement after implementing NSNotification

-(void) moveFileFromPathAsNewOriginalFile:(NSString*) path{
    
    NSString* originalPath = self.fileSystemPath_original;
    
    if(originalPath == NULL){
        DDLogError(@"File operation was attempted on attachment with null filesystem path (key: %@)", self.key);
        return;
    }

    NSAssert2([[NSFileManager defaultManager] fileExistsAtPath:path],@"Attempted to associate non-existing file from %@ with attachment %@", path,self.key);
    
    DDLogInfo(@"Moving file from %@ as a new server file %@ for item %@",path,self.fileSystemPath_original,self.key);
    
    [[NSFileManager defaultManager] removeItemAtPath:originalPath error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:path toPath:originalPath error:NULL];

    //Set this file as not cached
    const char* filePath = [originalPath fileSystemRepresentation];
    const char* attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
    setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);

}

-(void) moveFileFromPathAsNewModifiedFile:(NSString*) path{
    
    NSString* modifiedPath = self.fileSystemPath_modified;
    
    if(modifiedPath == NULL){
        DDLogError(@"File operation was attempted on attachment with null filesystem path (key: %@)", self.key);
        return;
    }
    
    NSAssert2([[NSFileManager defaultManager] fileExistsAtPath:path],@"Attempted to associate non-existing file from %@ with attachment %@", path,self.key);
    [[NSFileManager defaultManager] removeItemAtPath:modifiedPath error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:path toPath:modifiedPath error:NULL];

    //Set this file as not cached
    const char* filePath = [modifiedPath fileSystemRepresentation];
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
    if(_linkMode == LINK_MODE_IMPORTED_URL && ([self.contentType isEqualToString:@"text/html"] ||
                                                              [self.contentType isEqualToString:@"application/xhtml+xml"])){
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
    
    BOOL isDirectory;
    if(! [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]){
        [NSException raise:@"File not found" format:@"Attempted to calculate MD5 sum for a non-existing file at %@",path];
    }
    else if(isDirectory){
        [NSException raise:@"Directory not allowed" format:@"Attempted to calculate MD5 sum for a directory at %@",path];
    }
        
    //TODO: Make sure that this does not leak memory
    
    NSString* md5 = (__bridge_transfer NSString*) FileMD5HashCreateWithPath((__bridge CFStringRef) path, FileHashDefaultChunkSizeForReadingData);
    return md5;
}

+(NSString*) zoteroBase64Encode:(NSString*)filename{
    return [[filename base64EncodedString] stringByAppendingString:@"%ZB64"];
}

+(NSString*) zoteroBase64Decode:(NSString*)filename{
    NSString* toBeDecoded = [filename substringToIndex:[filename length] - 5];
    NSData* decodedData = [toBeDecoded base64DecodedData];
    NSString* decodedFilename = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
    return decodedFilename;
}


-(void) logFileRevisions{
//    DDLogInfo(@"MD5: %@ Server: %@ Local %@: Filename %@",self.md5,self.versionIdentifier_server,self.versionIdentifier_local,self.filename);
}

@end

