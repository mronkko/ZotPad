//
//  ZPFileUploadManager.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 1/5/13.
//
//

#import "ZPFileUploadManager.h"

//File uploading and downloading
#import "ZPFileChannel.h"
#import "ZPReachability.h"

#import "ZPServerConnection.h"
#import "ZPFileCacheManager.h"

@interface ZPFileUploadManager ()

+(void) _uploadVersionOfAttachment:(ZPZoteroAttachment*)attachment;
+(void) _scanFilesToUpload;

@end

@implementation ZPFileUploadManager

static ZPCacheStatusToolbarController* _statusView;

+(void) setStatusView:(ZPCacheStatusToolbarController*) statusView{
    _statusView = statusView;
}

+(void)initialize{
        
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyUserInterfaceAvailable:)
                                                 name:ZPNOTIFICATION_USER_INTERFACE_AVAILABLE
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyUserInterfaceAvailable:)
                                                 name:ZPNOTIFICATION_INTERNET_CONNECTION_AVAILABLE
                                               object:nil];

    
    
}

+(void) addAttachmentToUploadQueue:(ZPZoteroAttachment*) attachment withNewFile:(NSURL*)urlToFile{
    
    //Cancel any previous upload of this file
    ZPFileChannel* uploadChannel = [ZPFileChannel fileChannelForAttachment:attachment];
    [uploadChannel cancelDownloadingAttachment:attachment];
    
    //Move the file to right place and increment cache size
    [ZPFileCacheManager storeModifiedFileForAttachment:attachment fromPath:[urlToFile path]];
    
    [self performSelectorInBackground:@selector(_scanFilesToUpload) withObject:NULL];
}

+(void) useProgressView:(UIProgressView*) progressView forUploadingAttachment:(ZPZoteroAttachment*)attachment{
    ZPFileChannel* uploadChannel = [ZPFileChannel fileChannelForAttachment:attachment];
    [uploadChannel useProgressView:progressView forUploadingAttachment:attachment];
}


#pragma mark - Private methods

/*
 Scans the document directory for locally modified files and builds a new set
 */

+(void) _scanFilesToUpload{
    
    BOOL shouldUpload = [ZPFileChannel activeUploads]==0 && [ZPReachability hasInternetConnection];

    NSString* _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_documentsDirectory error:NULL];
    
    NSInteger count = 0;
    
    for (NSString* _documentFilePath in directoryContent) {
        ZPZoteroAttachment* attachment = [ZPZoteroAttachment dataObjectForAttachedFile:_documentFilePath];
        if(attachment !=NULL && [[attachment.fileSystemPath_modified lastPathComponent] isEqualToString:_documentFilePath]){
            count++;
            if(shouldUpload){
                DDLogInfo(@"Preparing to upload file %@.",attachment.filename);
                [self _uploadVersionOfAttachment:attachment];
            }
            else{
                DDLogInfo(@"File %@ will remain in the upload queue because the uploader is busy.",attachment.filename);
            }
        }
    }
    [_statusView setFileUploads:count];
}

//End of what needs to be refactored

#pragma mark - Asynchronous uploading of files

+(void) _uploadVersionOfAttachment:(ZPZoteroAttachment*)attachment{
    
    //If the local file does not exist, raise an exception as this should not happen.
    if(![[NSFileManager defaultManager] fileExistsAtPath:attachment.fileSystemPath_modified]){
        [NSException raise:@"File not found" format:@"File to be uploaded to Zotero server cannot be found"];
    }
    //Check if the file can be uploaded
    
    if([ZPPreferences debugFileUploads]) DDLogInfo(@"Retrieving new metadata for file %@.",attachment.filename);
    
    [ZPServerConnection retrieveSingleItem:attachment completion:^(NSArray* parsedResults) {
        if(parsedResults == NULL || [parsedResults count]==0){
            //Failure
            DDLogWarn(@"Failed retrieving metadata for file %@.",attachment.filename);
            [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_FAILED object:attachment];

        }
        else{
            //Success
            ZPZoteroAttachment* updatedAttachment = [parsedResults objectAtIndex:0];
            if([ZPPreferences debugFileUploads]) DDLogInfo(@"Starting upload sequence for %@.",updatedAttachment.filename);
            ZPFileChannel* uploadChannel = [ZPFileChannel fileChannelForAttachment:updatedAttachment];
            [uploadChannel startUploadingAttachment:updatedAttachment overWriteConflictingServerVersion:FALSE];
            [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_STARTED object:updatedAttachment];
            
        }
    }];
}

#pragma mark - Callbacks

+(void) finishedUploadingAttachment:(ZPZoteroAttachment*)attachment withVersionIdentifier:(NSString*)identifier{
    
    if(attachment == nil){
        [NSException raise:@"Attachment cannot be null" format:@"File upload returned with null attachmnet"];
    }
    if(identifier == nil){
        [NSException raise:@"Identifier cannot be null" format:@"File upload returned with null identifier"];
    }
    
    DDLogInfo(@"Finished uploading file %@",attachment.filename);
    
    //Update the timestamps and copy files into right place
    
    attachment.versionIdentifier_server = identifier;
    attachment.versionIdentifier_local = identifier;
    [ZPDatabase writeVersionInfoForAttachment:attachment];
    
    [ZPFileCacheManager storeOriginalFileForAttachment:attachment fromPath:attachment.fileSystemPath_modified];
    
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_FINISHED object:attachment];
    [self performSelectorInBackground:@selector(_scanFilesToUpload) withObject:NULL];

}

+(void) failedUploadingAttachment:(ZPZoteroAttachment*)attachment withError:(NSError*) error toURL:(NSString*)url{
    DDLogError(@"Failed uploading file %@. %@ (URL: %@) Troubleshooting instructions: http://www.zotpad.com/troubleshooting",attachment.filename,error.localizedDescription,url);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_FAILED object:attachment userInfo:error.userInfo];
    [self performSelectorInBackground:@selector(_scanFilesToUpload) withObject:NULL];

}


+(void) canceledUploadingAttachment:(ZPZoteroAttachment*)attachment{
    
    DDLogWarn(@"Uploading file %@ was canceled.",attachment.filename);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_FAILED object:attachment];
    [self performSelectorInBackground:@selector(_scanFilesToUpload) withObject:NULL];
}

#pragma mark - Notifications

+(void)notifyUserInterfaceAvailable:(NSNotification*)notification{
    [self performSelectorInBackground:@selector(_scanFilesToUpload) withObject:NULL];
}


@end
