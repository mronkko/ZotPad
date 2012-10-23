//
//  ZPCache.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//
//  This file manages item metadata retrieval.
//  
//  The metadata retrieval works with the following logic. Each library and each
//  collection has a cache timestamp that is initially null. When a user selects
//  a collection (This document uses a convention where library root is also
//  considered to be a collection, the CacheController receives a request for
//  list of uncached items for the item list that will be displayed to the user.
//  CacheController will then retrieve the most recenly modified item for that
//  collection. If this is the same as timestamp as the collection timestamp,
//  we know that the cache is up to date and there is no need to refresh it. In
//  this case, we return an empty array as the uncached keys.
//  
//  If the timestamp of the most recent item differs from the timestamp of the
//  collection we will obtain a list of item keys that belong to that collection
//  from the server. Then we check the items in this list against the cache and
//  add the items to the beginning of item retrieval queue and return this list
//  to the user interface class initially requesting the list of uncached items.
//  Then we refresh the collection memberships in the cache and set the
//  collection timestamp to the value of the most recent item timestamp. 
//
//  If the timestamp of the most recent item is more recent than the library
//  timestamp, we know that the cache for this library needs to be refreshed.
//  This is done by retrieving a list of item keys in the library ordered by the
//  modification date. The timestamp of the last modified item is stored as a
//  new library timestamp, but not written to the cache yet. All items whose
//  keys are not in the list of item keys are purged from the cache and the
//  items from this list that do not yet exist in the item retrieval queue are
//  added to the queue.
//  
//  The item retrieval queue is continuosly processed in the background and
//  notifications are sent to the Zotero user interface and other registered
//  classes when new or updated items become available. Every item that is 
//  retrieved from the server is checked against the timestamp that we stored 
//  and against the cache. If the timestamp for the received item is more recent
//  than the timestamp we will set a flag to redo the library cache update.
//  (This means that the server data has changed during our refresh, which is
//  rare) If the timestamp of a received item is equal to the old library 
//  timestamp, we know that we have received all updated items and can cancel
//  rest of the item retrieval and write an updated library timestamp in the
//  cache. If we have the flag for redoing the cache update set, the process
//  for refreshing the cache is repeated.
//
//  (This description is not updated for the current cahce logic)

#import "ZPCore.h"


#import "ZPCacheController.h"
#import "ZPPreferences.h"

#import "ZPDatabase.h"
#import "ZPServerResponseXMLParser.h"
#import "ZPServerConnectionManager.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroAttachment.h"
#import "ZPZoteroNote.h"

#define NUMBER_OF_ITEMS_TO_RETRIEVE 50
#define NUMBER_OF_PARALLEL_REQUESTS 8


@interface ZPCacheController (){
    NSInteger _activelibraryID;
    NSString* _activeCollectionKey;
    NSString* _activeItemKey;
    
    //Variables indicating if we are currently refreshing lobraries and collections from server
    ZPCacheStatusToolbarController* _statusView;
}

// Check if there is something to dowload or upload
-(void) _checkQueues;

// Starts the cache building
-(void) _start;

// Metadata

-(void) _checkMetadataQueue;


-(void) _checkIfLibraryNeedsCacheRefreshAndQueue:(NSInteger) libraryID;
-(void) _checkIfCollectionNeedsCacheRefreshAndQueue:(NSString*)collectionKey;


//Attachment Downloads and uploads
-(void) _checkDownloadQueue;
-(void) _checkUploadQueue;
-(void) _scanFilesToUpload;

-(void) _checkIfAttachmentsExistWithParentKeysAndQueueForDownload:(NSArray*)parentKeys;
-(void) _checkIfAttachmentExistsAndQueueForDownload:(ZPZoteroAttachment*)attachment;

- (unsigned long long int) _documentsFolderSize;
- (void) _scanAndSetSizeOfDocumentsFolder;
- (void) _updateCacheSizePreference;
- (void) _cleanUpCache;
- (void) _updateCacheSizeAfterAddingAttachment:(ZPZoteroAttachment*)attachment;


@end

@implementation ZPCacheController

static ZPCacheController* _instance = nil;

-(id)init
{
    self = [super init];
    
    
    //These collections contain things that we need to cache. These have been checked so that we know that they are either missing or outdated
    
    _itemKeysToRetrieve = [[NSMutableDictionary alloc] init];
    _libraryTimestamps = [[NSMutableDictionary alloc] init];

    _librariesToCache = [[NSMutableArray alloc] init];
    _collectionsToCache = [[NSMutableArray alloc] init];
    _filesToDownload = [[NSMutableArray alloc] init];
    _attachmentsToUpload = [[NSMutableSet alloc] init];
    
    _sizeOfDocumentsFolder = 0;

    return self;
}

/*
 Singleton accessor
 */

+(ZPCacheController*) instance {
    if(_instance == NULL){
        _instance = [[ZPCacheController alloc] init];
        [_instance performSelectorInBackground:@selector(_start) withObject:NULL];
    }
    return _instance;
}

-(void) _start{
    [self _scanAndSetSizeOfDocumentsFolder];
    [self performSelectorInBackground:@selector(_scanFilesToUpload) withObject:NULL];
    [self performSelectorInBackground:@selector(_cleanUpCache) withObject:NULL];
	
    [ZPServerConnectionManager retrieveLibrariesFromServer];
    
    /*
     Start building cache immediately if the user has chosen to cache all libraries
     */
    
    if([ZPPreferences cacheAttachmentsAllLibraries] || [ZPPreferences cacheMetadataAllLibraries]){
        NSArray* libraries = [ZPDatabase libraries];
        
        ZPZoteroLibrary* library;
        for(library in libraries){
            if([ZPPreferences cacheAttachmentsAllLibraries]){
                NSArray* itemKeysToCheck = [ZPDatabase getItemKeysForLibrary:library.libraryID collectionKey:NULL searchString:NULL orderField:NULL sortDescending:FALSE];
                [self _checkIfAttachmentsExistWithParentKeysAndQueueForDownload:itemKeysToCheck];
            }
            if([ZPPreferences cacheMetadataAllLibraries]){
                [self _checkIfLibraryNeedsCacheRefreshAndQueue:library.libraryID];
            }
        }
    }
    

}
-(void) setStatusView:(ZPCacheStatusToolbarController*) statusView{
    _statusView = statusView;
    
    NSInteger maxCacheSize = [ZPPreferences maxCacheSize];
    NSInteger cacheSizePercent = _sizeOfDocumentsFolder*100/ maxCacheSize;
    [_statusView setCacheUsed:cacheSizePercent];

}

/*
 
 Checks if there are things to cache and starts processing these if there is something to retrieve.
 
*/

-(void) _checkQueues{

    if([NSThread isMainThread]){
        [self performSelectorInBackground:@selector(_checkQueues) withObject:NULL];
    }
    else{
        [self _checkDownloadQueue];
        [self _checkMetadataQueue];
        [self _checkUploadQueue];
    }
}

-(void) _checkDownloadQueue{
    @synchronized(_filesToDownload){

        [_statusView setFileDownloads:[_filesToDownload count]];

//        DDLogVerbose(@"There are %i files in cache download queue",[_filesToDownload count]);

        if([_filesToDownload count]>0){
            //Only cache up to 95% full
            if(_sizeOfDocumentsFolder < 0.95*[ZPPreferences maxCacheSize]){
//                DDLogVerbose(@"There is space on device");
                if([ZPServerConnectionManager hasInternetConnection] && [ZPServerConnectionManager numberOfFilesDownloading] <1){
                    ZPZoteroAttachment* attachment = [_filesToDownload objectAtIndex:0];
                    [_filesToDownload removeObjectAtIndex:0];
                    while ( ![ZPServerConnectionManager checkIfCanBeDownloadedAndStartDownloadingAttachment:attachment] && [_filesToDownload count] >0){
                        DDLogWarn(@"File %@ (key: %@) belonging to item %@ (key: %@)  could not be found for download",attachment.filename,attachment.key,[(ZPZoteroItem*)[ZPZoteroItem itemWithKey:attachment.parentKey] fullCitation],attachment.parentKey);
                        attachment = [_filesToDownload objectAtIndex:0];
                        [_filesToDownload removeObjectAtIndex:0];
                    }
                }
            }        
        }
    }    
}

-(void) _checkUploadQueue{
    @synchronized(_attachmentsToUpload){
        
        //TODO: Update the views only when the number of items in the queue actually changes.
        [_statusView setFileUploads:[_attachmentsToUpload count]];
        
//        DDLogVerbose(@"Checked upload queue: Files to upload %i",[_attachmentsToUpload count]);
        
        if([_attachmentsToUpload count]>0){
            if([ZPServerConnectionManager hasInternetConnection] && [ZPServerConnectionManager numberOfFilesUploading] <1){
                ZPZoteroAttachment* attachment = [_attachmentsToUpload anyObject];
                //Remove from queue and upload
                [_attachmentsToUpload removeObject:attachment];
                [ZPServerConnectionManager uploadVersionOfAttachment:attachment];
                
            }
        }        
    }    
}


-(void) _checkMetadataQueue{
    
    BOOL continueRetrieving;
    while([ZPServerConnectionManager numberOfActiveMetadataRequests]<= NUMBER_OF_PARALLEL_REQUESTS && continueRetrieving){
        
        continueRetrieving = FALSE;
        @synchronized(_librariesToCache){
            if([_librariesToCache count]>0){
                
                [self _doContainerRetrieval:[_librariesToCache lastObject]];
                [_librariesToCache removeLastObject];
                continueRetrieving = TRUE;
            }
        }

        //Choose the queue the active library or choose a first non-empty queue
        
        @synchronized(_itemKeysToRetrieve){
            
            NSInteger itemsToDownload=0;
            for(NSObject* key in _itemKeysToRetrieve){
                itemsToDownload += [(NSArray*)[_itemKeysToRetrieve objectForKey:key] count];
            }
            
            [_statusView setItemDownloads:itemsToDownload];
            
            //Choose a library to retrieve
            NSMutableArray* keyArray = [_itemKeysToRetrieve objectForKey:[NSNumber numberWithInt:_activelibraryID]];
            NSEnumerator* e = [_itemKeysToRetrieve keyEnumerator];
            NSInteger libraryID = _activelibraryID;
            
            //If the active library does not have anything to retrieve, loop over all libraries to see if there is something to retrieve
            
            while(keyArray == NULL || [keyArray count]==0){
                if( !( libraryID = [[e nextObject] integerValue])){
                    break;
                    
                }
                keyArray = [_itemKeysToRetrieve objectForKey:[NSNumber numberWithInt:libraryID]];
                
                
            }
            
            //If we found a non-empty que, queue item retrival
            if(keyArray != NULL && [keyArray count]>0){
                
                if(libraryID == LIBRARY_ID_NOT_SET){
                    [NSException raise:@"LibraryID cannot be NULL" format:@""];
                }
                
                NSArray* keysToRetrieve;
                @synchronized(keyArray){
                    NSRange range = NSMakeRange(0, MIN(NUMBER_OF_ITEMS_TO_RETRIEVE,[keyArray count]));
                    keysToRetrieve = [keyArray subarrayWithRange:range];
                    
                    //Remove the items that we are retrieving
                    [keyArray removeObjectsInRange:range];
                    
                    //If the array became empty, mark this library as completely cached
                    if([keyArray count]==0){
                        NSNumber* keyObject = [NSNumber numberWithInt:libraryID];
                        NSString* timestamp = [_libraryTimestamps objectForKey:keyObject];
                        if(timestamp!=NULL){
                            //Update both the DB and the in-memory cache.
                            [ZPDatabase setUpdatedTimestampForLibrary:libraryID toValue:timestamp];
                            [[ZPZoteroLibrary libraryWithID:libraryID] setCacheTimestamp:timestamp];
                            DDLogVerbose(@"Library %i is now fully cached", libraryID);
                            [_libraryTimestamps removeObjectForKey:keyObject];
                        }
                    }
                    
                }
                
                [ZPServerConnectionManager retrieveItemsFromLibrary:libraryID itemKeys:keysToRetrieve];
                continueRetrieving = TRUE;

            }
            
        }
        
        // Last, check collection memberships
        @synchronized(_collectionsToCache){
            
            if([_collectionsToCache count]>0){
                
                [self _doContainerRetrieval:[_collectionsToCache lastObject]];
                [_collectionsToCache removeLastObject];
                continueRetrieving = TRUE;

            }
        }
    }
}



/*
 
 Retrieves container memberships. This does not automatically queue items retrievals because
 all items will be retieved for libraries anyway based on the date modified.
 
 */

- (void) _doContainerRetrieval:(NSObject*) container{
    
    //Is it a library or a collection
    NSString* collectionKey = NULL;
    NSInteger libraryID = LIBRARY_ID_NOT_SET;
    
    if([container isKindOfClass:[ZPZoteroLibrary class]]){
        libraryID = [(ZPZoteroLibrary*)container libraryID];
    }
    else{
        libraryID = [(ZPZoteroCollection*)container libraryID];
        collectionKey = [(ZPZoteroCollection*)container key];
    }
    
    [ZPServerConnectionManager retrieveTimestampForLibrary:libraryID collection:collectionKey];
    
}

-(void) refreshActiveItem:(ZPZoteroItem*) item {
    
    if(item == NULL){
        [NSException raise:@"Item cannot be null" format:@"MethodrefreshActiveItem  was called with an argument that was null."];
    }
    
    
    [ZPServerConnectionManager retrieveSingleItemDetailsFromServer:item];
}

-(void) setActiveLibrary:(NSInteger)libraryID collection:(NSString*)collectionKey{

    
    
    if(libraryID !=_activelibraryID && ! [ZPPreferences cacheAttachmentsAllLibraries] ){
        @synchronized(_filesToDownload){
            [_filesToDownload removeAllObjects];
        }
        //        DDLogVerbose(@"Clearing attachment download queue because library changed and preferences do not indicate that all libraries should be downloaded");
    }
    
    //Store the libraryID and collectionKEy
    _activelibraryID = libraryID;
    
    //Both keys might be null, so we need to compare equality directly as well
    if(! (collectionKey == _activeCollectionKey || [collectionKey isEqual:_activeCollectionKey]) && ! [ZPPreferences cacheAttachmentsActiveLibrary]){
        @synchronized(_filesToDownload){
            
            [_filesToDownload removeAllObjects];
        }
        //        DDLogVerbose(@"Clearing attachment download queue because collection changed and preferences do not indicate that all collections should be downloaded");
    }
    _activeCollectionKey = collectionKey;
    
    //Add attachments to queue

    //TODO: Refactor so that this block is not needed
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{

        NSArray* itemKeysToCheck = [ZPDatabase getItemKeysForLibrary:libraryID collectionKey:collectionKey searchString:NULL orderField:NULL sortDescending:FALSE];
        [self _checkIfAttachmentsExistWithParentKeysAndQueueForDownload:itemKeysToCheck];
        
        //Check if the container needs a refresh
        if(collectionKey == NULL){
            [self _checkIfLibraryNeedsCacheRefreshAndQueue:libraryID];
        }
        else{
            [self _checkIfCollectionNeedsCacheRefreshAndQueue:collectionKey];
        }

    });
    
}
-(void) _checkIfAttachmentsExistWithParentKeysAndQueueForDownload:(NSArray*)parentKeys{

    for(NSString* key in parentKeys){
        ZPZoteroItem* item = (ZPZoteroItem*) [ZPZoteroItem itemWithKey:key];

        //Troubleshooting
        
        //TODO: Remove this workaround
        NSArray* attachments = item.attachments;
        if(attachments == NULL){
            [NSException raise:@"Internal consistency exception" format:@"Item with key %@ had empty attachment array",key];
        }
        if(! [attachments isKindOfClass:[NSArray class]]){
            //For troubleshooting crashes
            item.attachments = NULL;
        }
        else{
            for(ZPZoteroAttachment* attachment in attachments){
                [self _checkIfAttachmentExistsAndQueueForDownload:attachment];
            }
        }
    }
}

-(void) _checkIfAttachmentExistsAndQueueForDownload:(ZPZoteroAttachment*)attachment{
    
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
            [self _checkQueues];
        }
    }
}

-(void) addAttachmentToDowloadQueue:(ZPZoteroAttachment *)attachment{

    @synchronized(_filesToDownload){
        
        [_filesToDownload removeObject:attachment];
        [_filesToDownload insertObject:attachment atIndex:0];
        //            DDLogVerbose(@"Queuing attachment download to %@, number of files in queue %i",attachment.fileSystemPath,[_filesToDownload count]);
    }    
}

-(void) addToLibrariesQueue:(ZPZoteroLibrary*)object priority:(BOOL)priority{
    //Check this library is already baing cached
    if([_libraryTimestamps objectForKey:[NSNumber numberWithInt:object.libraryID]] == NULL){
        DDLogVerbose(@"Adding library %@ to the metadata retrieval queue",object.title);
        @synchronized(_librariesToCache){
            if(priority){
                [_librariesToCache removeObject:object];
                [_librariesToCache addObject:object];
            }
            else if(! [_librariesToCache containsObject:object]){
                [_librariesToCache insertObject:object atIndex:0]; 
            }
        }
    }
}


-(void) addToCollectionsQueue:(ZPZoteroCollection*)object priority:(BOOL)priority{

    @synchronized(_collectionsToCache){
        if(priority){
            [_collectionsToCache removeObject:object];
            [_collectionsToCache addObject:object];
        }
        else if(! [_collectionsToCache containsObject:object]){
            [_collectionsToCache insertObject:object atIndex:0]; 
        }
    }
}

-(void) addToItemQueue:(NSArray*)itemKeys libraryID:(NSInteger)libraryID priority:(BOOL)priority{

    @synchronized(_itemKeysToRetrieve){
        NSMutableArray* targetArray = [_itemKeysToRetrieve objectForKey:[NSNumber numberWithInt:libraryID]];
        if(targetArray == NULL){
            targetArray = [NSMutableArray array];
            [_itemKeysToRetrieve setObject:targetArray forKey:[NSNumber numberWithInt:libraryID]];               
        }
        
        if(priority){
            [targetArray removeObjectsInArray:itemKeys];
            [targetArray insertObjects:itemKeys atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,[itemKeys count])]];
        }
        else{
            NSMutableArray* checkedKeys= [NSMutableArray arrayWithArray: itemKeys];
            [checkedKeys removeObjectsInArray:targetArray];
            [targetArray addObjectsFromArray:checkedKeys];
        }
    }
    [self _checkQueues];
}

-(void) _checkIfLibraryNeedsCacheRefreshAndQueue:(NSInteger) libraryID{
   
    [ZPServerConnectionManager retrieveTimestampForLibrary:libraryID collection:NULL];
}

-(void) _checkIfCollectionNeedsCacheRefreshAndQueue:(NSString*)collectionKey{
 
    ZPZoteroCollection* container = (ZPZoteroCollection*) [ZPZoteroCollection collectionWithKey:collectionKey];
    NSInteger libraryID = container.libraryID;
    
    if(libraryID == LIBRARY_ID_NOT_SET) [NSException raise:@"libraryID for collection object was null" format:@"This should not happen"];
    
    //Get the time stamp to see if we need to retrieve more
    
    [ZPServerConnectionManager retrieveTimestampForLibrary:libraryID collection:collectionKey];

    
}

    
#pragma mark - Metadata callbacks

//Called by server connections to process new data
-(void) processNewItemsFromServer:(NSArray*)items forLibraryID:(NSInteger)libraryID{
        
    
    DDLogVerbose(@"Writing %i items to cache",[items count]);
    
    ZPZoteroItem* item;
    
    NSMutableArray* normalItems = [NSMutableArray array];
    NSMutableArray* attachments = [NSMutableArray array];
    NSMutableArray* notes = [NSMutableArray array];
    NSMutableArray* parentItemsForAttachments = [NSMutableArray array];
    NSMutableArray* parentItemsForNotes = [NSMutableArray array];

    for(item in items){
        if( [item needsToBeWrittenToCache]){
            
            //TODO: Refactor. This is very confusing.
            //TODO: Make sure that this logic still works after breaking inheritance between attachment and item
            
            item.cacheTimestamp = item.serverTimestamp;
            
            if([item isKindOfClass:[ZPZoteroAttachment class]]){
                ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) item;
                
                [attachments addObject:attachment];
                [self _checkIfAttachmentExistsAndQueueForDownload:attachment];
                
                ZPZoteroItem* parent;
                //Standalone attachments
                
                if(attachment.parentKey!=attachment.key){
                    parent =  [ZPZoteroItem itemWithKey:attachment.parentKey];
                    if(![parentItemsForAttachments containsObject:parent]) [parentItemsForAttachments addObject:parent];
                }
            }
            //If this is a note item, store the note information
            else if([item isKindOfClass:[ZPZoteroNote class]]){
                ZPZoteroNote* note = (ZPZoteroNote*) item;
                [notes addObject:note];
                
                //Standalone notes
                
                ZPZoteroItem* parent;
                
                if(note.parentKey!=note.key){
                    parent = (ZPZoteroItem*) [ZPZoteroItem itemWithKey:note.parentKey];
                    if(![parentItemsForNotes containsObject:parent]) [parentItemsForNotes addObject:parent];
                }
                
                
            }
            //Normal item
            else{
                [normalItems addObject:item];
            }
        }
    }
    
    [ZPDatabase writeAttachments:attachments];
    [ZPDatabase writeNotes:notes];
    
    NSArray* topLevelItemsThatWereWrittenToCache = [ZPDatabase writeItems:normalItems];
    NSMutableArray* itemsThatNeedCreatorsAndFields = [NSMutableArray arrayWithArray:topLevelItemsThatWereWrittenToCache];
    
    [ZPDatabase writeItemsFields:itemsThatNeedCreatorsAndFields];
    [ZPDatabase writeItemsCreators:itemsThatNeedCreatorsAndFields];
    
    //TODO: Also Notes and attachments can have tags
    [ZPDatabase writeDataObjectsTags:itemsThatNeedCreatorsAndFields];
    
    //Refresh the attachments for those items that got new attachments
    for(item in parentItemsForAttachments){
        [ZPDatabase addAttachmentsToItem:item];
    }
    for(item in parentItemsForNotes){
        [ZPDatabase addNotesToItem:item];
    }
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:ZPNOTIFICATION_ITEMS_AVAILABLE
     object:[[topLevelItemsThatWereWrittenToCache arrayByAddingObjectsFromArray:parentItemsForNotes]arrayByAddingObjectsFromArray:parentItemsForAttachments]];
    
    [self _checkQueues];
    

}
-(void) processNewLibrariesFromServer:(NSArray*)libraries{
    
        
    NSEnumerator* e = [libraries objectEnumerator];
    
    ZPZoteroLibrary* library;
    
    while ( library = (ZPZoteroLibrary*) [e nextObject]) {
        [ZPServerConnectionManager retrieveCollectionsForLibraryFromServer:library.libraryID];
    }

    [ZPDatabase writeLibraries:libraries];
    
    while ( library = (ZPZoteroLibrary*) [e nextObject]) {
        if([ZPPreferences cacheMetadataAllLibraries]){
            [self _checkIfLibraryNeedsCacheRefreshAndQueue:library.libraryID];
        }
        
    }
    [self _checkQueues];

}
-(void) processNewCollectionsFromServer:(NSArray*)collections forLibraryID:(NSInteger)libraryID;{
    
    ZPZoteroLibrary* library = [ZPZoteroLibrary libraryWithID:libraryID];
    [ZPDatabase writeCollections:collections toLibrary:library];

    [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_LIBRARY_WITH_COLLECTIONS_AVAILABLE object:library];
    [self _checkQueues];

    
}

/*

 Processes a list containing all keys in a library
 
 */

-(void) processNewItemKeyListFromServer:(NSArray*)serverKeys forLibraryID:(NSInteger) libraryID{

    [ZPDatabase deleteItemKeysNotInArray:serverKeys fromLibrary:libraryID];
    
    //If there is data in the library, start cacheing it
    
    if([serverKeys count]>0){
        
        //Get all keys in the library
        NSArray* cacheKeys = [ZPDatabase getAllItemKeysForLibrary:libraryID];
        
        //How far along the key list we want to retrieve
        NSString* markerKey = [ZPDatabase getFirstItemKeyWithTimestamp:[[ZPZoteroLibrary libraryWithID:libraryID] cacheTimestamp] from:libraryID];
        
        //Iterate the arrays backward until we find a difference
        NSInteger index = [serverKeys indexOfObject:markerKey];
        
        //Sanity check
        if(index == NSNotFound){
            index = [serverKeys count];
        }
        
        NSArray* itemKeysThatNeedToBeRetrieved = [serverKeys subarrayWithRange:NSMakeRange(0, index)];
        
        // First add all items that do not exist in the cache
        NSMutableArray* nonExistingKeys = [NSMutableArray arrayWithArray:itemKeysThatNeedToBeRetrieved];
        [nonExistingKeys removeObjectsInArray:cacheKeys];
        if([nonExistingKeys count]>0){
            [self addToItemQueue:nonExistingKeys libraryID:libraryID priority:FALSE];
            DDLogVerbose(@"Added %i non-existing keys that need data",[nonExistingKeys count]);
        }
        
        // Then add the rest of the items
        NSMutableArray* existingKeys = [NSMutableArray arrayWithArray:itemKeysThatNeedToBeRetrieved];
        [existingKeys removeObjectsInArray:nonExistingKeys];
        if([existingKeys count]>0){
            [self addToItemQueue:existingKeys libraryID:libraryID priority:FALSE];
            DDLogVerbose(@"Added %i existing keys that might need new data",[existingKeys count]);
        }
        
    }

    [self _checkQueues];

}
-(void) processNewTopLevelItemKeyListFromServer:(NSArray*)itemKeys userInfo:(NSDictionary*)parameters{

    NSString* collectionKey = [parameters objectForKey:ZPKEY_COLLECTION_KEY];
    NSInteger libraryID = [[parameters objectForKey:ZPKEY_LIBRARY_ID] integerValue];
    
    //Update collection memberships
    if(collectionKey!=NULL && [parameters objectForKey: ZPKEY_SEARCH_STRING] == NULL){
        NSArray* cachedKeys = [ZPDatabase getItemKeysForLibrary:libraryID collectionKey:collectionKey searchString:NULL orderField:NULL sortDescending:FALSE];
        
        NSMutableArray* uncachedItems = [NSMutableArray arrayWithArray:itemKeys];
        [uncachedItems removeObjectsInArray:cachedKeys];
        
        if([uncachedItems count]>0) [ZPDatabase addItemKeys:uncachedItems toCollection:collectionKey];
        if([itemKeys count] >0) [ZPDatabase removeItemKeysNotInArray:itemKeys fromCollection:collectionKey];
    }

    [[NSNotificationCenter defaultCenter]
     postNotificationName:ZPNOTIFICATION_ITEM_LIST_AVAILABLE
     object:itemKeys
     userInfo:parameters];
    
    //Queue these items for retrieval
    [self addToItemQueue:itemKeys libraryID:libraryID priority:YES];
    [self _checkQueues];

}

/*
 Compares a timestamp agains cached timestamp and stars retrieving data if needed
 */
-(void) processNewTimeStampForLibrary:(NSInteger)libraryID collection:(NSString*)collectionKey timestampValue:(NSString*)newTimestamp{

    //Library timestamp
    
    if(collectionKey==NULL){
        //Check that we are not already cacheing this item.

        NSNumber* keyObj = [NSNumber numberWithInt:libraryID];
        
        if([_libraryTimestamps objectForKey:keyObj]==NULL){
        
            [_libraryTimestamps setObject:newTimestamp forKey:keyObj];
   
            DDLogVerbose(@"Checking if we need to cache library %i",libraryID);
            [ZPServerConnectionManager retrieveAllItemKeysFromLibrary:libraryID];
        
            
            //Retrieve collections
            
            ZPZoteroLibrary* container = (ZPZoteroLibrary*) [ZPZoteroLibrary libraryWithID:libraryID];
            
            if(![newTimestamp isEqualToString:container.cacheTimestamp]){
                
                [self addToLibrariesQueue:container priority:FALSE];
                
                if([ZPPreferences cacheMetadataActiveLibrary]){
                    
                    //Retrieve all collections for this library and add them to cache
                    for(ZPZoteroCollection* collection in [ZPDatabase collectionsForLibrary:container.libraryID]){
                        [ZPServerConnectionManager retrieveTimestampForLibrary:libraryID collection:collection.key];
                    }
                }
            }

        }
        
    }
    
    //Collection timestamp
    
    else{
        ZPZoteroCollection* collection = [ZPZoteroCollection collectionWithKey:collectionKey];
        if(![newTimestamp isEqualToString:collection.cacheTimestamp]){
            [ZPServerConnectionManager retrieveKeysInLibrary:libraryID collection:collectionKey];
            [ZPDatabase setUpdatedTimestampForCollection:collectionKey toValue:newTimestamp];
        }
    }
    
    [self _checkQueues];
}


#pragma mark -
#pragma mark Notifier methods for metadata



-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library{
    if([ZPPreferences cacheMetadataAllLibraries]){
        [self _checkIfLibraryNeedsCacheRefreshAndQueue:library.libraryID];
        [self _checkQueues];
    }
}




#pragma mark -
#pragma mark Attachment cache

//TODO: refactor these methods. Remove those that are not used and convert others to use NSNotification

-(void) notifyAttachmentDownloadCompleted:(ZPZoteroAttachment*) attachment{
    if(attachment.fileExists) [self _updateCacheSizeAfterAddingAttachment:attachment];
    [self performSelectorInBackground:@selector(_checkQueues) withObject:NULL];
}

-(void) notifyAttachmentDownloadFailed:(ZPZoteroAttachment *)attachment withError:(NSError *)error{
    [self performSelectorInBackground:@selector(_checkQueues) withObject:NULL];
}
-(void) notifyAttachmentUploadFailed:(ZPZoteroAttachment *)attachment withError:(NSError *)error{
    [self performSelectorInBackground:@selector(_checkQueues) withObject:NULL];

}
-(void) notifyAttachmentUploadCompleted:(ZPZoteroAttachment *)attachment{
    [self performSelectorInBackground:@selector(_checkQueues) withObject:NULL];
}
-(void) notifyAttachmentUploadCanceled:(ZPZoteroAttachment *)attachment{
    [self performSelectorInBackground:@selector(_checkQueues) withObject:NULL];
}

-(void) notifyAttachmentDownloadStarted:(ZPZoteroAttachment*) attachment{
}


-(void) notifyAttachmentUploadStarted:(ZPZoteroAttachment*) attachment{
    
}

               
-(void) notifyAttachmentDeleted:(ZPZoteroAttachment*) attachment fileAttributes:(NSDictionary*) fileAttributes{
    if(_sizeOfDocumentsFolder!=0){
        
        _sizeOfDocumentsFolder += [fileAttributes fileSize]/1024;
        [self _updateCacheSizePreference];
    }
}

- (void) purgeAllAttachmentFilesFromCache{
    
    NSString* _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_documentsDirectory error:NULL];
    
    for (NSString* _documentFilePath in directoryContent) {
        //Leave database, database journal, and log files
        if(! [@"zotpad.sqlite" isEqualToString: _documentFilePath] && ! [_documentFilePath isEqualToString:@"zotpad.sqlite-journal"] && ! [_documentFilePath hasPrefix:@"log-"]){
            [[NSFileManager defaultManager] removeItemAtPath:[_documentsDirectory stringByAppendingPathComponent:_documentFilePath] error:NULL];
        }
    }
    [self _scanAndSetSizeOfDocumentsFolder];
}

- (void) _scanAndSetSizeOfDocumentsFolder{
    _sizeOfDocumentsFolder = [self _documentsFolderSize];
    
    [self _updateCacheSizePreference];
}

- (void) _updateCacheSizePreference{
    
    
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

- (unsigned long long int) _documentsFolderSize {

    NSString* _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_documentsDirectory error:NULL];

    unsigned long long int _documentsFolderSize = 0;
    
    for (NSString* _documentFilePath in directoryContent) {
        NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[_documentsDirectory stringByAppendingPathComponent:_documentFilePath] error:NULL];
        NSInteger thisSize = [_documentFileAttributes fileSize]/1024;
        _documentsFolderSize += thisSize;
        //DDLogVerbose(@"Cache size is %i after including %@ (%i)",(NSInteger) _documentsFolderSize,_documentFilePath,thisSize);
    }
    
    return _documentsFolderSize;
}

- (void) _updateCacheSizeAfterAddingAttachment:(ZPZoteroAttachment*)attachment{
    if(_sizeOfDocumentsFolder!=0){
        
        NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:attachment.fileSystemPath error:NULL];
        _sizeOfDocumentsFolder += [_documentFileAttributes fileSize]/1024;
//        DDLogInfo(@"Cache size is %i KB after adding %@ (%i KB)",(NSInteger)_sizeOfDocumentsFolder,attachment.fileSystemPath,[_documentFileAttributes fileSize]/1024);


//        DDLogVerbose(@"Cache size after adding %@ to cache is %i",attachment.fileSystemPath,_sizeOfDocumentsFolder);

        if(_sizeOfDocumentsFolder>=[ZPPreferences maxCacheSize]) [self _cleanUpCache];
        [self _updateCacheSizePreference];
    }
}

- (void) _cleanUpCache{
    
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
                NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:NULL];
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
            [attachment purge_original:@"Automatic cache cleaning to reclaim space"];
            
            if (_sizeOfDocumentsFolder<=[ZPPreferences maxCacheSize]) break;
        }
    }
    DDLogWarn(@"Done cleaning cached files");

}

-(void) addAttachmentToUploadQueue:(ZPZoteroAttachment*) attachment withNewFile:(NSURL*)urlToFile{

    //Move the file to right place and increment cache size
    [attachment moveFileFromPathAsNewModifiedFile:[urlToFile path]];

    //TODO: Refactor cache size modifications to notifications
    NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:attachment.fileSystemPath_modified error:NULL];
    _sizeOfDocumentsFolder -= [_documentFileAttributes fileSize]/1024;

    //Add to upload queue
    @synchronized(_attachmentsToUpload){
        [_attachmentsToUpload addObject:attachment];
    }
    [self performSelectorInBackground:@selector(_checkQueues) withObject:NULL];
}

/*
 Scans the document directory for locally modified files and builds a new set
 */

-(void) _scanFilesToUpload{
    @synchronized(_attachmentsToUpload){
        [_attachmentsToUpload removeAllObjects];
    }
    NSString* _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_documentsDirectory error:NULL];
    
    for (NSString* _documentFilePath in directoryContent) {
        ZPZoteroAttachment* attachment = [ZPZoteroAttachment dataObjectForAttachedFile:_documentFilePath];
        if(attachment !=NULL && [[attachment.fileSystemPath_modified lastPathComponent] isEqualToString:_documentFilePath]){
            @synchronized(_attachmentsToUpload){
                [_attachmentsToUpload addObject:attachment]; 
            }
        }
    }
    [self performSelectorInBackground:@selector(_checkQueues) withObject:NULL];
}


@end
