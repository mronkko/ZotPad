//
//  ZPFileCacheManager.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 1/5/13.
//
//

#import "ZPFileCacheManager.h"
#include <sys/xattr.h>

@interface ZPFileCacheManager()

+(unsigned long long int) _documentsFolderSize;
+(void) _scanAndSetSizeOfDocumentsFolder;
+(void) _updateCacheSizePreference;
+(void) _cleanUpCache;
+(void) _addFileToCacheFromPath:(NSString*)fromPath toPath:(NSString*) toPath;
+(void) _deleteFileFromPath:(NSString*)path;

@end


@implementation ZPFileCacheManager

// Size of the folder in kilobytes
static unsigned long long int _sizeOfDocumentsFolder = 0;

static ZPCacheStatusToolbarController* _statusView;

+(void)initialize{
    //Set the cache size and clean up
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{
        [self _scanAndSetSizeOfDocumentsFolder];
        [self _cleanUpCache];
    });
}

+(void) setStatusView:(ZPCacheStatusToolbarController*) statusView{
    _statusView = statusView;
    
    NSInteger maxCacheSize = [ZPPreferences maxCacheSize];
    NSInteger cacheSizePercent = _sizeOfDocumentsFolder*100/ maxCacheSize;
    [_statusView setCacheUsed:cacheSizePercent];
    
}

+(BOOL) isCacheLimitReached{
    return _sizeOfDocumentsFolder > 0.95*[ZPPreferences maxCacheSize];
}


+(void) purgeAllAttachmentFilesFromCache{
    
    NSString* _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_documentsDirectory error:NULL];
    
    for (NSString* _documentFilePath in directoryContent) {
        //Leave database, database journal, and log files
        if(! [@"zotpad.sqlite" isEqualToString: _documentFilePath] && ! [_documentFilePath isEqualToString:@"zotpad.sqlite-journal"] && ! [_documentFilePath hasPrefix:@"log-"]){
            [self _deleteFileFromPath:[_documentsDirectory stringByAppendingPathComponent:_documentFilePath]];
        }
    }
    //Refresh the size of the documents folder
    [self _scanAndSetSizeOfDocumentsFolder];
}


+(void) deleteOriginalFileForAttachment:(ZPZoteroAttachment*)attachment reason:(NSString*) reason{

    if([attachment fileExists_original]){
        [self _deleteFileFromPath:attachment.fileSystemPath_original];
        [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_DELETED object:attachment];
        DDLogWarn(@"File %@ (version from server) was deleted: %@",attachment.filename,reason);
    }

}

+(void) deleteModifiedFileForAttachment:(ZPZoteroAttachment*)attachment reason:(NSString*) reason{

    if([attachment fileExists_modified]){
        [self _deleteFileFromPath:attachment.fileSystemPath_modified];
        [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_DELETED object:attachment];
        DDLogWarn(@"File %@ (locally modified) was deleted: %@",attachment.filename,reason);
    }

}

+(void) storeOriginalFileForAttachment:(ZPZoteroAttachment*)attachment fromPath:(NSString*)path{

    //Delete the original
    if([attachment fileExists_original]){
        [self deleteOriginalFileForAttachment:attachment reason:@"Replacing with a new version"];
    }
    
    //If we are just moving a file inside the cache, then do not update the cahce size
    
    if([path isEqualToString:attachment.fileSystemPath_modified]){
        [[NSFileManager defaultManager] moveItemAtPath:path toPath:attachment.fileSystemPath_original error:NULL];
    }
    else{
        [self _addFileToCacheFromPath:path toPath:attachment.fileSystemPath_original];
    }
    
    // For the UI the effect of moving a file is the same as downloading it
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FINISHED object:attachment];

}

+(void) storeModifiedFileForAttachment:(ZPZoteroAttachment*)attachment fromPath:(NSString*)path{
    //Delete the original
    if([attachment fileExists_modified]){
        [self deleteOriginalFileForAttachment:attachment reason:@"Replacing with a locally received file"];
    }
    
    [self _addFileToCacheFromPath:path toPath:attachment.fileSystemPath_modified];
    
}


#pragma mark - Internal methods

+(void) _addFileToCacheFromPath:(NSString*)fromPath toPath:(NSString*) toPath{
    [[NSFileManager defaultManager] moveItemAtPath:fromPath toPath:toPath error:NULL];

    //Set this file as not cached
    const char* filePath = [toPath fileSystemRepresentation];
    const char* attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
    setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);

    NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:toPath error:NULL];
    _sizeOfDocumentsFolder += [_documentFileAttributes fileSize]/1024;
    
    if(_sizeOfDocumentsFolder>=[ZPPreferences maxCacheSize]) [self _cleanUpCache];
    [self _updateCacheSizePreference];


}

+(void) _deleteFileFromPath:(NSString*)path{
    NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    _sizeOfDocumentsFolder -= [_documentFileAttributes fileSize]/1024;
    [[NSFileManager defaultManager] removeItemAtPath:path error: NULL];
}

+(void) _scanAndSetSizeOfDocumentsFolder{
    _sizeOfDocumentsFolder = [self _documentsFolderSize];
    [self _updateCacheSizePreference];
}

+(void) _updateCacheSizePreference{
    
    //Smaller than one gigabyte
    if(_sizeOfDocumentsFolder < 1048576){
        NSInteger temp = _sizeOfDocumentsFolder/1024;
        [ZPPreferences setCurrentCacheSize:[NSString stringWithFormat:@"%i MB",temp]];
        
    }
    else{
        float temp = ((float)_sizeOfDocumentsFolder)/1048576;
        [ZPPreferences setCurrentCacheSize:[NSString stringWithFormat:@"%.1f GB",temp]];
    }
    //Also update the view if it has been defined
    if(_statusView !=NULL){
        NSInteger maxCacheSize = [ZPPreferences maxCacheSize];
        NSInteger cacheSizePercent = _sizeOfDocumentsFolder*100/ maxCacheSize;
        [_statusView setCacheUsed:cacheSizePercent];
    }
}

/*
 
 Source: http://stackoverflow.com/questions/2188469/calculate-the-size-of-a-folder
 
 */

+(unsigned long long int) _documentsFolderSize {
    
    NSString* _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_documentsDirectory error:NULL];
    
    unsigned long long int _documentsFolderSize = 0;
    
    for (NSString* _documentFilePath in directoryContent) {
        NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[_documentsDirectory stringByAppendingPathComponent:_documentFilePath] error:NULL];
        NSInteger thisSize = [_documentFileAttributes fileSize]/1024;
        _documentsFolderSize += thisSize;
        //DDLogVerbose(@"Cache size is %i after including %@ (%i)",(NSInteger) _documentsFolderSize,_documentFilePath,thisSize);
    }
    
    return _documentsFolderSize;
}

+(void) _cleanUpCache{
    
    DDLogWarn(@"Start cleaning cached files");
    
    NSArray* attachments = [ZPDatabase getCachedAttachmentsOrderedByRemovalPriority];
    
    //Store file system paths in array so that we do not need to do a million calls on attachment.filesystemPath, but use cached results
    
    NSMutableArray* attachmentPaths = [[NSMutableArray alloc] initWithCapacity:[attachments count]];
    
    ZPZoteroAttachment* attachment;
    
    for(attachment in attachments){
        [attachmentPaths addObject:attachment.fileSystemPath];
    }
    //Delete orphaned files
    
    NSString* _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_documentsDirectory error:NULL];
    
    
    for (NSString* _documentFilePath in directoryContent) {
        NSString* path = [_documentsDirectory stringByAppendingPathComponent:_documentFilePath];
        
        if(! [_documentFilePath isEqualToString: @"zotpad.sqlite"] && ! [_documentFilePath isEqualToString:@"zotpad.sqlite-journal"] && ! [_documentFilePath hasPrefix:@"log-"]){
            
            // The strings from DB and file system have different encodings. Because of this, we cannot scan the array using built-in functions, but need to loop over it
            NSString* pathFromDB;
            BOOL found = FALSE;
            
            for(pathFromDB in attachmentPaths){
                if([pathFromDB compare:path] == NSOrderedSame){
                    found=TRUE;
                    break;
                }
            }
            
            // If the file was not found in DB, delete it
            
            if(! found){
                NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
                _sizeOfDocumentsFolder -= [_documentFileAttributes fileSize]/1024;
                //                DDLogWarn(@"Deleting orphaned file %@. Cache use is now at %i\%",path,_sizeOfDocumentsFolder*100/[ZPPreferences maxCacheSize]);
                [[NSFileManager defaultManager] removeItemAtPath:path error: NULL];
            }
        }
    }
    
    
    //Delete attachment files until the size of the cache is below the maximum size
    NSInteger maxCacheSize =[ZPPreferences maxCacheSize];
    if (_sizeOfDocumentsFolder>maxCacheSize){
        for(attachment in attachments){
            
            //Only delete originals
            [self deleteOriginalFileForAttachment:attachment reason:@"Automatic cache cleaning to reclaim space"];
            
            if (_sizeOfDocumentsFolder<=[ZPPreferences maxCacheSize]) break;
        }
    }
    DDLogWarn(@"Done cleaning cached files");
    
}

#pragma mark - Notifications



@end
