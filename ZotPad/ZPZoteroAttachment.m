//
//  ZPZoteroAttachment.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//



#import "ZPCore.h"

#import "FileMD5Hash.h"
#import "ZPItemDataDownloadManager.h"
#import "Base64.h"

#import "ZPFileCacheManager.h"

//Needed for UTIs

#import <MobileCoreServices/MobileCoreServices.h>

NSInteger const LINK_MODE_IMPORTED_FILE = 0;
NSInteger const LINK_MODE_IMPORTED_URL = 1;
NSInteger const LINK_MODE_LINKED_FILE = 2;
NSInteger const LINK_MODE_LINKED_URL = 3;

NSInteger const VERSION_SOURCE_ZOTERO =1;
NSInteger const VERSION_SOURCE_WEBDAV =2;
NSInteger const VERSION_SOURCE_DROPBOX =3;

@interface ZPZoteroAttachment(){
    NSString* _contentType;
}

- (NSString*) _fileSystemPathWithSuffix:(NSString*)suffix;

//This returns a file name or title based on link mode.
- (NSString*) filenameBasedOnLinkMode;

@end


@implementation ZPZoteroAttachment

static NSCache* _objectCache = NULL;
static NSString* _documentsDirectory = NULL;

@synthesize lastViewed, attachmentSize, existsOnZoteroServer, filename, url, versionSource,  charset, note, md5, mtime, linkMode;
@synthesize versionIdentifier_server;
@synthesize versionIdentifier_local;
@synthesize accessDate ;

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

-(void) setContenType:(NSString*)contentType{
    _contentType = contentType;
}

-(NSString*) contentType{
    if(_contentType == nil){
        
        //set text/HTML as the default type for links

        if(_linkMode ==LINK_MODE_LINKED_URL){
            _contentType = @"text/html";
        }
        
        //else determine from the filename
        
        else{
             
             // Get the UTI from the file's extension:
        
             CFStringRef pathExtension = (__bridge_retained CFStringRef)[self.filename pathExtension];
            
            if(pathExtension != NULL){
                CFStringRef type = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension, NULL);
                CFRelease(pathExtension);
                
                // The UTI can be converted to a mime type:
        
                if (type != NULL){
                    _contentType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(type, kUTTagClassMIMEType);
                    CFRelease(type);
                }
            }
        }
    }
    
    return _contentType;
}

- (NSInteger) libraryID{
    //Child attachments
    if(super.libraryID==ZPLIBRARY_ID_NOT_SET){
        if(self.parentKey != NULL){
            return [ZPZoteroItem itemWithKey:self.parentKey].libraryID;
        }
        else {
            [NSException raise:@"Internal consistency error" format:@"Standalone items must have library IDs. Standalone attachment with key %@ had a null library ID",self.key];
            return ZPLIBRARY_ID_NOT_SET;
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
    NSArray* keyCandidates =[parsedFilename componentsSeparatedByString: @"_"];
    
    //Reverse iterate the key candidates. It is possible that something has been
    //appended at the end by the PDF editor
    
    for(NSString* keyCandidate in [keyCandidates reverseObjectEnumerator]){
    
        //The key cannot be in the first element
        if(keyCandidate == [keyCandidates objectAtIndex:0]) return NULL;

        //Only process filename parts that are long enough to be keys

        if(keyCandidate.length>=8){
         
            //Trim extra characters
            
            ZPZoteroAttachment* attachment = [self attachmentWithKey:[keyCandidate substringToIndex:8]];
            
            if([attachment filenameBasedOnLinkMode] != NULL ) return attachment;

        }
    }
    return NULL;
}

- (NSString*) fileSystemPath{
    NSString* modified =[self fileSystemPath_modified];
    if([[NSFileManager defaultManager] fileExistsAtPath:modified]) return modified;
    else return [self fileSystemPath_original];
}

- (NSString*) _fileSystemPathWithSuffix:(NSString*)suffix{
    
    //Linked files do not have file names, only titles
    
    NSString* thisFilename = [self filenameBasedOnLinkMode];


    if(thisFilename == NULL)
        return NULL;
    
    // Some iOS features require that the file UTI should be identified based on
    // the filename. Check that we can actually do this and if not, add the
    // proper suffix.
    
    NSString* fileNameExtension = [thisFilename pathExtension];

    if(fileNameExtension != NULL){

        if([fileNameExtension isEqualToString:@""]){
            fileNameExtension = NULL;
        }
        else{
            NSString* UTI = (__bridge NSString*) UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                                           (__bridge CFStringRef) fileNameExtension,
                                                                           NULL);
            if(UTI == NULL){
                fileNameExtension = NULL;
            }
        }
    }

    //Add file name extension if it could not be mapped to an UTI and if we the
    //content type is known. 
    
    if(fileNameExtension == NULL && self.contentType != nil){

        CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType,
                                                                (__bridge CFStringRef) self.contentType,
                                                                NULL);
        
        if(UTI != NULL){
            fileNameExtension = (__bridge NSString*) UTTypeCopyPreferredTagWithClass(UTI,
                                                                                 kUTTagClassFilenameExtension);
            CFRelease(UTI);
            
            if(fileNameExtension != nil){
                thisFilename = [thisFilename stringByAppendingPathExtension:fileNameExtension];
            }
        }
    }

    NSString* path;
    
    
    //Imported URLs are stored as ZIP files
    
    if(_linkMode == LINK_MODE_IMPORTED_URL && ([self.contentType isEqualToString:@"text/html"]
                                                              || [self.contentType isEqualToString:@"application/xhtml+xml"])){
        path = [thisFilename stringByAppendingFormat:@"_%@%@.zip",self.key,suffix];
    }
    else{
        NSRange lastPeriod = [thisFilename rangeOfString:@"." options:NSBackwardsSearch];
        
        
        if(lastPeriod.location == NSNotFound){
            path = [thisFilename stringByAppendingFormat:@"_%@%@",self.key,suffix];
        }
        else{
            path = [thisFilename stringByReplacingCharactersInRange:lastPeriod
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

//If an attachment is updated, delete the old attachment file

- (void) setServerTimestamp:(NSString*)timestamp{
    [super setServerTimestamp:timestamp];
    if(![self.serverTimestamp isEqual:self.cacheTimestamp] && [self fileExists_original]){
        //If the file MD5 does not match the server MD5, delete it.
        NSString* fileMD5 = [ZPZoteroAttachment md5ForFileAtPath:self.fileSystemPath_original];
        if(self.md5 == NULL || ! [self.md5 isEqualToString:fileMD5]){
            [ZPFileCacheManager deleteOriginalFileForAttachment:self reason:@"Server version has changed"];
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

    return [ZPZoteroAttachment zoteroBase64Encode:filename];
}

#pragma mark - File operations

- (NSString*) filenameBasedOnLinkMode{
    if(self.linkMode == LINK_MODE_LINKED_FILE){
        return self.title;
    }
    else{
        return self.filename;
    }
}

-(BOOL) fileExists{
    //If there is no known filename for the item, then the item cannot exists in cache
    if(self.filenameBasedOnLinkMode == nil || self.filenameBasedOnLinkMode == (NSObject*)[NSNull null]){
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
    if(self.filenameBasedOnLinkMode == nil || self.filenameBasedOnLinkMode == (NSObject*)[NSNull null]){
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
    if(self.filenameBasedOnLinkMode == nil || self.filenameBasedOnLinkMode == (NSObject*)[NSNull null]){
        return false;
    }
    NSString* fsPath = [self fileSystemPath_modified];
    if(fsPath == NULL)
        return false; 
    else
        return ([[NSFileManager defaultManager] fileExistsAtPath:fsPath]);
}


-(BOOL)locallyAdded{ return FALSE;}
-(BOOL)locallyModified{ return FALSE;}
-(BOOL)locallyDeleted{ return FALSE;}


-(BOOL) isPDF{
    return [self.contentType isEqualToString:@"application/pdf"];
}

#pragma mark - QLPreviewItem protocol

-(NSURL*) previewItemURL{
    
    //Return path to uncompressed files.
    //TODO: Encapsulate as a method
    if(_linkMode == LINK_MODE_IMPORTED_URL && ([self.contentType isEqualToString:@"text/html"] ||
                                                              [self.contentType isEqualToString:@"application/xhtml+xml"])){
        NSString* tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:self.key];
        
        return [NSURL fileURLWithPath:[tempDir stringByAppendingPathComponent:self.filenameBasedOnLinkMode]];
    }
    else return [NSURL fileURLWithPath:self.fileSystemPath];
}

-(NSString*) previewItemTitle{
    return self.filenameBasedOnLinkMode;
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

