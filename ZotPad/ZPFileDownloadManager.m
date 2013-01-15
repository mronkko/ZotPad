//
//  ZPFileDownloadManager.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 1/5/13.
//
//

#import "ZPFileDownloadManager.h"
#import "ZPFileCacheManager.h"

#import "ZPReachability.h"

#import "ZPFileChannel.h"


@interface ZPFileDownloadManager ()

+(void) _checkDownloadQueue;
+(void) _checkIfAttachmentsExistWithParentKeysAndQueueForDownload:(NSArray*)parentKeys;
+(void) _checkIfAttachmentExistsAndQueueForDownload:(ZPZoteroAttachment*)attachment;

@end

@implementation ZPFileDownloadManager


static NSInteger _activelibraryID;
static NSString* _activeCollectionKey;
static NSString* _activeItemKey;

static NSMutableArray* _filesToDownload;
static NSMutableSet* _activeDownloads;

static ZPCacheStatusToolbarController* _statusView;

+(void) setStatusView:(ZPCacheStatusToolbarController*) statusView{
    _statusView = statusView;
}

+(void)initialize{

    _filesToDownload = [[NSMutableArray alloc] init];
    _activeDownloads= [[NSMutableSet alloc] init];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{
        [self _checkDownloadQueue];
    });

    // Register for active item, collection, and library changes so that we know how to do predictive downloading
    
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyActiveItemChanged:)
                                                 name:ZPNOTIFICATION_ACTIVE_ITEM_CHANGED
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyActiveCollectionChanged:)
                                                 name:ZPNOTIFICATION_ACTIVE_COLLECTION_CHANGED
                                               object:nil];

    
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyActiveLibraryChanged:)
                                                 name:ZPNOTIFICATION_ACTIVE_LIBRARY_CHANGED
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyUserInterfaceAvailable:)
                                                 name:ZPNOTIFICATION_USER_INTERFACE_AVAILABLE
                                               object:nil];

    // Listen for new items so that we know to start downloading
    
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyAttachmentsAvailable:)
                                                 name:ZPNOTIFICATION_ATTACHMENTS_AVAILABLE
                                               object:nil];
    
    // Listen for completed downloads so that we know to start next download
    
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyAttachmentDownloadFinished:)
                                                 name:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FINISHED
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyAttachmentDownloadFailed:)
                                                 name:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FAILED
                                               object:nil];

}

+(void) addAttachmentToDowloadQueue:(ZPZoteroAttachment *)attachment{
    
    @synchronized(_filesToDownload){
        
        [_filesToDownload removeObject:attachment];
        [_filesToDownload insertObject:attachment atIndex:0];
        //            DDLogVerbose(@"Queuing attachment download to %@, number of files in queue %i",attachment.fileSystemPath,[_filesToDownload count]);
    }
}

#pragma mark - Internal methods

/*
 
 Checks if there are things to cache and starts processing these if there is something to retrieve.
 
 */

+(void) _checkDownloadQueue{
    @synchronized(_filesToDownload){
        
        [_statusView setFileDownloads:[_filesToDownload count]];
        
        //        DDLogVerbose(@"There are %i files in cache download queue",[_filesToDownload count]);
        
        if([_filesToDownload count]>0){
            if(! [ZPFileCacheManager isCacheLimitReached]){
                if([ZPReachability hasInternetConnection] && [ZPFileChannel activeDownloads] <1){
                    ZPZoteroAttachment* attachment = [_filesToDownload objectAtIndex:0];
                    [_filesToDownload removeObjectAtIndex:0];
                    while ( ![self checkIfCanBeDownloadedAndStartDownloadingAttachment:attachment] && [_filesToDownload count] >0){
                        DDLogWarn(@"File %@ (key: %@) belonging to item %@ (key: %@)  could not be found for download",attachment.filename,attachment.key,[(ZPZoteroItem*)[ZPZoteroItem itemWithKey:attachment.parentKey] fullCitation],attachment.parentKey);
                        attachment = [_filesToDownload objectAtIndex:0];
                        [_filesToDownload removeObjectAtIndex:0];
                    }
                }
            }
        }
    }
}

+(void) _checkIfAttachmentsExistWithParentKeysAndQueueForDownload:(NSArray*)parentKeys{
    
    for(NSString* key in parentKeys){
        ZPZoteroItem* item = (ZPZoteroItem*) [ZPZoteroItem itemWithKey:key];
        
        NSArray* attachments = item.attachments;
        
        for(ZPZoteroAttachment* attachment in attachments){
            [self _checkIfAttachmentExistsAndQueueForDownload:attachment];
        }
    }
}

+(void) _checkIfAttachmentExistsAndQueueForDownload:(ZPZoteroAttachment*)attachment{
    
    if(! attachment.fileExists){
        BOOL doCache=false;
        //Cache based on preferences
        if([ZPPreferences cacheAttachmentsAllLibraries]){
            doCache = true;
        }
        else if([ZPPreferences cacheAttachmentsActiveLibrary]){
            doCache = (attachment.libraryID == _activelibraryID);
            
        }
        //Check if the parent belongs to active the collection
        else if([ZPPreferences cacheAttachmentsActiveCollection]){
            ZPZoteroItem* parent = (ZPZoteroItem*)[ZPZoteroItem itemWithKey:attachment.parentKey];
            if(parent.libraryID == _activelibraryID && _activeCollectionKey == NULL){
                doCache=true;
            }
            else if(_activeCollectionKey!= NULL && [parent.collections containsObject:[ZPZoteroCollection collectionWithKey:_activeCollectionKey] ]){
                doCache = true;
            }
        }
        else if([ZPPreferences cacheAttachmentsActiveItem]){
            doCache =( attachment.parentKey == _activeItemKey);
        }
        
        if(doCache){
            [self addAttachmentToDowloadQueue:attachment];
            [self _checkDownloadQueue];
        }
    }
}

#pragma mark - Asynchronous file downloads


+(BOOL) checkIfCanBeDownloadedAndStartDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    DDLogVerbose(@"Checking if file %@ can download",attachment);
    
    //Check if the file can be downloaded
    
    if(attachment.linkMode  == LINK_MODE_LINKED_URL || (attachment.linkMode == LINK_MODE_LINKED_FILE && ! [ZPPreferences downloadLinkedFilesWithDropbox])){
        return FALSE;
    }
    
    // This can happen if the data on the server or local Zotero are corrupted.
    else if(attachment.fileSystemPath_original == NULL){
        [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FAILED
                                                            object:attachment
                                                          userInfo:[NSDictionary dictionaryWithObject:@"Zotero server did not provide a filename."
                                                                                               forKey:NSLocalizedDescriptionKey]];
        
        return FALSE;
    }
    
    ZPFileChannel* downloadChannel = [ZPFileChannel fileChannelForAttachment:attachment];
    
    if(downloadChannel == NULL){
        return FALSE;
    }
    
    @synchronized(_activeDownloads){
        //Do not download item if it is already being downloaded
        if([_activeDownloads containsObject:attachment]){
            return false;
        }
        DDLogVerbose(@"Added %@ to active downloads. Number of files downloading is %i",attachment.filename,[_activeDownloads count]);
        [_activeDownloads addObject:attachment];
    }
    
    
    DDLogVerbose(@"Checking downloading %@ with filechannel %i",attachment.filename,downloadChannel.fileChannelType);
    [downloadChannel startDownloadingAttachment:attachment];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_STARTED object:attachment];
    
    return TRUE;
}

/*
 This is called always when an item finishes downloading regardless of whether it was succcesful or not.
 */
+(void) finishedDownloadingAttachment:(ZPZoteroAttachment*)attachment toFileAtPath:(NSString*) tempFile withVersionIdentifier:(NSString*) identifier{
    
    if(tempFile == NULL){
        [NSException raise:@"Invalid file path" format:@"File channel should not report success if file was not received"];
    }
    else if(identifier == NULL){
        [NSException raise:@"Invalid version identifier" format:@"File channel must report version identifier on succesful download"];
    }
    else{
        //If we got a file, move it to the right place
        
        NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:tempFile error:NULL];
        
        if([_documentFileAttributes fileSize]>0){
            
            //Move the file to the right place
            [ZPFileCacheManager storeOriginalFileForAttachment:attachment fromPath:tempFile];
            
            //Write version info to DB
//            attachment.versionSource = fileChannel.fileChannelType;
            attachment.versionIdentifier_server = identifier;
            
            [ZPDatabase writeVersionInfoForAttachment:attachment];
            
        }
        @synchronized(_activeDownloads){
            [_activeDownloads removeObject:attachment];
            DDLogVerbose(@"Finished downloading %@",attachment.filename);
        }
        
        //We need to do this in a different thread so that the current thread does not count towards the operations count
        [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FINISHED object:attachment];
        
    }
    
    
}

+(void) failedDownloadingAttachment:(ZPZoteroAttachment*)attachment withError:(NSError*) error fromURL:(NSString *)url{
    @synchronized(_activeDownloads){
        [_activeDownloads removeObject:attachment];
        DDLogError(@"Failed downloading file %@. %@ (URL: %@) Troubleshooting instructions: http://www.zotpad.com/troubleshooting",attachment.filename,error.localizedDescription,url);
    }
    
    //We need to do this in a different thread so that the current thread does not count towards the operations count
    [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FAILED object:attachment userInfo:error.userInfo];
    
    
}


+(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    //Loop over the file channels and cancel downloading of this attachment
    ZPFileChannel* downloadChannel = [ZPFileChannel fileChannelForAttachment:attachment];
    [downloadChannel cancelDownloadingAttachment:attachment];
}

+(void) useProgressView:(UIProgressView*) progressView forDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    ZPFileChannel* downloadChannel = [ZPFileChannel fileChannelForAttachment:attachment];
    [downloadChannel  useProgressView:progressView forDownloadingAttachment:attachment];
}

+(BOOL) isAttachmentDownloading:(ZPZoteroAttachment*)attachment{
    @synchronized(_activeDownloads){
        return [_activeDownloads containsObject:attachment];
    }
    
}

#pragma mark - Notifications

+(void) notifyAttachmentsAvailable:(NSNotification *) notification{
    //Apply the rules to see if we want to download this
    NSArray* items = notification.object;
    for(ZPZoteroAttachment* item in items){
        [self _checkIfAttachmentExistsAndQueueForDownload:(ZPZoteroAttachment*) item];
    }

}


+(void) notifyActiveLibraryChanged:(NSNotification *) notification{
    
    NSInteger libraryID = [(NSNumber*) notification.object integerValue];
    
    if(libraryID !=_activelibraryID && ! [ZPPreferences cacheAttachmentsAllLibraries] ){
        @synchronized(_filesToDownload){
            [_filesToDownload removeAllObjects];
        }
        DDLogVerbose(@"Clearing attachment download queue because library changed and preferences do not indicate that all libraries should be downloaded");
    }
    
    _activelibraryID = libraryID;
    
    //Add attachments to queue
    
    if([ZPPreferences cacheAttachmentsActiveLibrary]){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{
            
            NSArray* itemKeysToCheck = [ZPDatabase getItemKeysForLibrary:_activelibraryID collectionKey:NULL searchString:NULL tags:NULL orderField:NULL sortDescending:FALSE];
            [self _checkIfAttachmentsExistWithParentKeysAndQueueForDownload:itemKeysToCheck];
            
        });
    }
}

+(void) notifyActiveCollectionChanged:(NSNotification *) notification{
    
    NSString* collectionKey =  notification.object;
    
    // Clear the download queue if we are only cacheing active collections and items
    // Both keys might be null, so we need to compare equality directly as well
    
    if(! (collectionKey == _activeCollectionKey || [collectionKey isEqual:_activeCollectionKey]) && ! [ZPPreferences cacheAttachmentsActiveLibrary]){
        @synchronized(_filesToDownload){
            [_filesToDownload removeAllObjects];
        }
        DDLogVerbose(@"Clearing attachment download queue because collection changed and preferences do not indicate that the active library should be downloaded");
    }
    
    _activeCollectionKey = collectionKey;
    
    if([ZPPreferences cacheAttachmentsActiveCollection]){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{
            NSArray* itemKeysToCheck = [ZPDatabase getItemKeysForLibrary:_activelibraryID collectionKey:_activeCollectionKey searchString:NULL tags:NULL orderField:NULL sortDescending:FALSE];
            [self _checkIfAttachmentsExistWithParentKeysAndQueueForDownload:itemKeysToCheck];
            [self _checkDownloadQueue];
        });
    }
    
}

+(void) notifyActiveItemChanged:(NSNotification *) notification{
    
    NSString* itemKey = [(ZPZoteroItem*) notification.object itemKey];
    
    // Clear the download queue if we are only cacheing active collections and items
    // Both keys might be null, so we need to compare equality directly as well
    
    if(! (itemKey == _activeItemKey || [itemKey isEqual:_activeItemKey]) && ! [ZPPreferences cacheAttachmentsActiveCollection]){
        @synchronized(_filesToDownload){
            [_filesToDownload removeAllObjects];
        }
        DDLogVerbose(@"Clearing attachment download queue because active item changed and preferences do not indicate that active collection should be downloaded");
    }
    
    _activeItemKey = itemKey;
    
    if([ZPPreferences cacheAttachmentsActiveItem]){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{
            [self _checkIfAttachmentsExistWithParentKeysAndQueueForDownload:[NSArray arrayWithObject:_activeItemKey]];
        });
    }
    
}

+(void) notifyUserInterfaceAvailable:(NSNotification*)notification{

    // Start building cache immediately if the user has chosen to cache all libraries
    
    if([ZPPreferences cacheAttachmentsAllLibraries]){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{
            for(ZPZoteroLibrary* library in [ZPDatabase libraries]){
                NSArray* itemKeysToCheck = [ZPDatabase getItemKeysForLibrary:library.libraryID collectionKey:NULL searchString:NULL tags:NULL orderField:NULL sortDescending:FALSE];
                [self _checkIfAttachmentsExistWithParentKeysAndQueueForDownload:itemKeysToCheck];
                [self _checkDownloadQueue];
            }
        });
    }
}

+(void) notifyAttachmentDownloadFinished:(NSNotification*)notification{
    [self _checkDownloadQueue];
}

+(void) notifyAttachmentDownloadFailed:(NSNotification*)notification{
    [self _checkDownloadQueue];
}


@end
