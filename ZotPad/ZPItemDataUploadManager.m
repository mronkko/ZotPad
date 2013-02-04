//
//  ZPItemDataUploadManager.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 1/5/13.
//
//

#import "ZPCore.h"
#import "ZPItemDataUploadManager.h"
#import "ZPServerConnection.h"

@interface ZPItemDataUploadManager ()

+(BOOL) _uploadCollections;
+(BOOL) _uploadAddItemsToCollections;
+(BOOL) _uploadRemoveItemsFromCollections;
+(BOOL) _uploadAttachmentNotes;
+(BOOL) _uploadNotes;
+(BOOL) _uploadTags;

@end


@implementation ZPItemDataUploadManager

//TODO: refactor this into ZPZoteroServerConnection
#define NUMBER_OF_PARALLEL_REQUESTS 9

+(void) setStatusView:(ZPCacheStatusToolbarController*)statusView{
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

+(void)notifyUserInterfaceAvailable:(NSNotification*)notification{
    [self uploadMetadata];
}

/*
 
 Scans for locally modified metadata and uploads it.
 
 */

+(void) uploadMetadata{
    
    // This does only one upload at a time because we have no reliable way of knowing which items are currently uploading
    
    if([ZPServerConnection numberOfActiveMetadataWriteRequests] == 0){
    
        [self _uploadCollections] ||
        [self _uploadAttachmentNotes] ||
        [self _uploadNotes] ||
        [self _uploadTags] ||
        [self _uploadRemoveItemsFromCollections] ||
        [self _uploadAddItemsToCollections];

    }
}

+(BOOL) _uploadCollections{
    
    NSArray* locallyModifiedCollections = [ZPDatabase locallyAddedCollections];
    
    if(locallyModifiedCollections.count >0 ){
        ZPZoteroCollection* locallyAddedCollection = [locallyModifiedCollections objectAtIndex:0];
        [ZPServerConnection createCollection:locallyAddedCollection completion:^(ZPZoteroCollection* serverVersionOfCollection) {

            [ZPDatabase replaceLocallyAddedCollection:locallyAddedCollection withServerVersion:serverVersionOfCollection];
            
            // Notify that the collections have been updated
            [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_LIBRARY_WITH_COLLECTIONS_AVAILABLE object:[ZPZoteroLibrary libraryWithID:serverVersionOfCollection.libraryID]];
            
            NSLog(@"Created collection %@", locallyAddedCollection.title);
            
            // Proceed with other uploads
            [self uploadMetadata];
        }];
        return TRUE;
    }
    else{
        return FALSE;
    }
}

+(BOOL) _uploadAttachmentNotes{
    return FALSE;
}

+(BOOL) _uploadNotes{
    return FALSE;
}

+(BOOL) _uploadTags{
    return FALSE;
}

+(BOOL) _uploadAddItemsToCollections{
    NSDictionary* locallyModifiedCollectionMemberships = [ZPDatabase locallyAddedCollectionMemberships];
    
    if(locallyModifiedCollectionMemberships.count >0 ){
        NSString* collectionKey = [locallyModifiedCollectionMemberships.keyEnumerator nextObject];
        NSArray* itemKeys = [locallyModifiedCollectionMemberships objectForKey:collectionKey];

        ZPZoteroCollection* collection = [ZPZoteroCollection collectionWithKey:collectionKey];

        [ZPServerConnection addItems:itemKeys toCollection:[ZPZoteroCollection collectionWithKey:collectionKey] completion:^{
            
            [ZPDatabase addItemKeys:itemKeys toCollection:collectionKey];

            DDLogInfo(@"Added %i item(s) to collection %@",[itemKeys count], collection.title);

            // Proceed with other uploads
            [self uploadMetadata];
        }];
        return TRUE;
    }
    else{
        return FALSE;
    }
}

+(BOOL) _uploadRemoveItemsFromCollections{

    NSDictionary* locallyModifiedCollectionMemberships = [ZPDatabase locallyDeletedCollectionMemberships];
    
    if(locallyModifiedCollectionMemberships.count >0 ){
        NSString* collectionKey = [locallyModifiedCollectionMemberships.keyEnumerator nextObject];
        NSArray* itemKeys = [locallyModifiedCollectionMemberships objectForKey:collectionKey];

        ZPZoteroCollection* collection = [ZPZoteroCollection collectionWithKey:collectionKey];
        
        [ZPServerConnection removeItem:[itemKeys objectAtIndex:0] fromCollection:collection completion:^{
            
            [ZPDatabase removeItemKey:[itemKeys objectAtIndex:0] fromCollection:collectionKey];

            DDLogInfo(@"Removed 1 item from collection %@", collection.title);
            
            // Proceed with other uploads
            [self uploadMetadata];
        }];
        return TRUE;
    }
    else{
        return FALSE;
    }
}


@end
