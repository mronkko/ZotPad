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


#import "ZPItemDataDownloadManager.h"
#import "ZPServerResponseXMLParser.h"
#import "ZPServerConnection.h"




#define NUMBER_OF_ITEMS_TO_RETRIEVE 50
#define NUMBER_OF_PARALLEL_REQUESTS 8


@interface ZPItemDataDownloadManager ()

+(void) _checkMetadataQueue;

// Check if we need to add things to queue

+(void) _checkIfLibraryNeedsCacheRefreshAndQueue:(NSInteger) libraryID;
+(void) _checkIfCollectionNeedsCacheRefreshAndQueue:(NSString*)collectionKey;

// Adding things to queues

+(void) _addToLibrariesQueue:(ZPZoteroLibrary*)object priority:(BOOL)priority;
+(void) _addToCollectionsQueue:(ZPZoteroCollection*)object priority:(BOOL)priority;
+(void) _addToItemQueue:(NSArray*)items libraryID:(NSInteger)libraryID priority:(BOOL)priority;

// Retrieve things

+(void) _doContainerRetrieval:(NSObject*) container;

+(void) _markLibraryAsFullyCachedAndCleanUp:(NSInteger)LibraryID;

@end

@implementation ZPItemDataDownloadManager

static NSInteger _activelibraryID;

//These two arrays contain a list of IDs/Keys that will be cached

static NSMutableDictionary* _itemKeysToRetrieve;
static NSMutableDictionary* _libraryTimestamps;

static NSMutableArray* _collectionsToCache;
static NSMutableArray* _librariesToCache;

static ZPCacheStatusToolbarController* _statusView;


+(void)initialize{

    //These collections contain things that we need to cache. These have been checked so that we know that they are either missing or outdated
    
    _itemKeysToRetrieve = [[NSMutableDictionary alloc] init];
    _libraryTimestamps = [[NSMutableDictionary alloc] init];

    _librariesToCache = [[NSMutableArray alloc] init];
    _collectionsToCache = [[NSMutableArray alloc] init];

    // Register for new libraries so that we know to cache them
    
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyLibraryWithCollectionsAvailable:)
                                                 name:ZPNOTIFICATION_LIBRARY_WITH_COLLECTIONS_AVAILABLE
                                               object:nil];
    
    // Register for active item changes so that we know to refresh the item
    
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyActiveItemChanged:)
                                                 name:ZPNOTIFICATION_ACTIVE_ITEM_CHANGED
                                               object:nil];
    
    // Register for library changes so that we know to adjust the cache building process
    
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyActiveLibraryChanged:)
                                                 name:ZPNOTIFICATION_ACTIVE_LIBRARY_CHANGED
                                               object:nil];

    /*
     
    //Collection are updated when a library is changed. Refreshing all collections every time a collection is changed is overkill
    
     [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyActiveCollectionChanged:)
                                                 name:ZPNOTIFICATION_ACTIVE_COLLECTION_CHANGED
                                               object:nil];
    */
    
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyAuthenticationSuccesful:)
                                                 name:ZPNOTIFICATION_ZOTERO_AUTHENTICATION_SUCCESSFUL
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyUserInterfaceAvailable:)
                                                 name:ZPNOTIFICATION_USER_INTERFACE_AVAILABLE
                                               object:nil];
    
}

+(void) setStatusView:(ZPCacheStatusToolbarController*) statusView{
    _statusView = statusView;
}

#pragma mark - Internal methods

+(void) _checkMetadataQueue{
    
    DDLogVerbose(@"Checking item data retrieval queue");
    
    BOOL continueRetrieving = TRUE;
    
    NSInteger metaDataRequests = [ZPServerConnection numberOfActiveMetadataRequests];
    
    while(metaDataRequests++ <= NUMBER_OF_PARALLEL_REQUESTS && continueRetrieving){

        DDLogVerbose(@"Number of active requests is %i, starting a new request",[ZPServerConnection numberOfActiveMetadataRequests]);

        continueRetrieving = FALSE;
        @synchronized(_librariesToCache){
            if([_librariesToCache count]>0){

                DDLogVerbose(@"Retrieving keys for library %i",[(ZPZoteroLibrary*)[_librariesToCache lastObject] libraryID]);

                [self _doContainerRetrieval:[_librariesToCache lastObject]];
                [_librariesToCache removeLastObject];
                continueRetrieving = TRUE;
            }
        }

        //Choose the queue the active library or choose a first non-empty queue
        
        @synchronized(_itemKeysToRetrieve){

//            DDLogVerbose(@"Acquired lock to items that need to be retrieved");
            
            NSInteger itemsToDownload=0;
            for(NSObject* key in _itemKeysToRetrieve){
                itemsToDownload += [(NSArray*)[_itemKeysToRetrieve objectForKey:key] count];
            }
            DDLogVerbose(@"Number of items that need retrieving is %i", itemsToDownload);
            
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
                        [self _markLibraryAsFullyCachedAndCleanUp:libraryID];
                    }
                    
                }
                
                [ZPServerConnection retrieveItemsFromLibrary:libraryID itemKeys:keysToRetrieve];
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
    DDLogVerbose(@"Finished checking the metadata download queue");
}

+(void) _markLibraryAsFullyCachedAndCleanUp:(NSInteger)libraryID{
    NSNumber* keyObject = [NSNumber numberWithInt:libraryID];
    NSString* timestamp = [_libraryTimestamps objectForKey:keyObject];
    if(timestamp!=NULL){
        
        ZPZoteroLibrary* library = [ZPZoteroLibrary libraryWithID:libraryID];
        
        //Update both the DB and the in-memory cache.
        if(library.cacheTimestamp == NULL || ![library.cacheTimestamp isEqualToString:timestamp]){
            [ZPDatabase setUpdatedTimestampForLibrary:libraryID toValue:timestamp];
            [library setCacheTimestamp:timestamp];
            DDLogInfo(@"%@ is now fully cached", library.title);
            [_libraryTimestamps removeObjectForKey:keyObject];
        }
    }
    
    //Remove the library from the item retrieval queue
    @synchronized(_itemKeysToRetrieve){
        [_itemKeysToRetrieve removeObjectForKey:[NSNumber numberWithInt:libraryID]];
    }
}


/*
 
 Retrieves container (library or collection) memberships. This does not automatically queue items retrievals because
 all items will be retrieved for libraries anyway based on the date modified.
 
 */

+(void) _doContainerRetrieval:(NSObject*) container{
    
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
    
    [ZPServerConnection retrieveTimestampForLibrary:libraryID collection:collectionKey];
    
}

+(void) _addToLibrariesQueue:(ZPZoteroLibrary*)object priority:(BOOL)priority{
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
    [self _checkMetadataQueue];
}


+(void) _addToCollectionsQueue:(ZPZoteroCollection*)object priority:(BOOL)priority{

    @synchronized(_collectionsToCache){
        if(priority){
            [_collectionsToCache removeObject:object];
            [_collectionsToCache addObject:object];
        }
        else if(! [_collectionsToCache containsObject:object]){
            [_collectionsToCache insertObject:object atIndex:0]; 
        }
    }
    [self _checkMetadataQueue];
}

+(void) _addToItemQueue:(NSArray*)itemKeys libraryID:(NSInteger)libraryID priority:(BOOL)priority{

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
    [self _checkMetadataQueue];
}

+(void) _checkIfLibraryNeedsCacheRefreshAndQueue:(NSInteger) libraryID{
   
    [ZPServerConnection retrieveTimestampForLibrary:libraryID collection:NULL];
}

+(void) _checkIfCollectionNeedsCacheRefreshAndQueue:(NSString*)collectionKey{
 
    ZPZoteroCollection* container = (ZPZoteroCollection*) [ZPZoteroCollection collectionWithKey:collectionKey];
    NSInteger libraryID = container.libraryID;
    
    if(libraryID == LIBRARY_ID_NOT_SET) [NSException raise:@"libraryID for collection object was null" format:@"This should not happen"];
    
    //Get the time stamp to see if we need to retrieve more
    
    [ZPServerConnection retrieveTimestampForLibrary:libraryID collection:collectionKey];

    
}

#pragma mark - Metadata callbacks

//Called by server connections to process new data
+(void) processNewItemsFromServer:(NSArray*)items forLibraryID:(NSInteger)libraryID{
        
    if([items count] ==0 ) return;
    
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
            
            if([item isKindOfClass:[ZPZoteroAttachment class]]){
                ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) item;
                
                [attachments addObject:attachment];
                
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
    
    [ZPDatabase writeAttachments:attachments checkTimestamp:YES];
    [ZPDatabase writeNotes:notes checkTimestamp:YES];
    
    NSArray* topLevelItemsThatWereWrittenToCache = [ZPDatabase writeItems:normalItems checkTimestamp:YES];
    NSMutableArray* itemsThatNeedCreatorsAndFields = [NSMutableArray arrayWithArray:topLevelItemsThatWereWrittenToCache];
    
    [ZPDatabase writeItemsFields:itemsThatNeedCreatorsAndFields];
    [ZPDatabase writeItemsCreators:itemsThatNeedCreatorsAndFields];
    
    [ZPDatabase writeDataObjectsTags:itemsThatNeedCreatorsAndFields];
    [ZPDatabase writeDataObjectsTags:attachments];

    //Refresh the attachments for those items that got new attachments
    for(item in parentItemsForAttachments){
        [ZPDatabase addAttachmentsToItem:item];
    }
    for(item in parentItemsForNotes){
        [ZPDatabase addNotesToItem:item];
    }
    
    NSArray* allItems = [[topLevelItemsThatWereWrittenToCache arrayByAddingObjectsFromArray:parentItemsForNotes]arrayByAddingObjectsFromArray:parentItemsForAttachments];
    
    // If the items list did not result in any new data and the time stamp of the last item is less than the
    // library timestamp, we know that the library is fully cached
    
    if([allItems count] == 0){
        ZPZoteroDataObject* lastItem =  [items lastObject];
        ZPZoteroLibrary* library = [ZPZoteroLibrary libraryWithID:lastItem.libraryID];
        
        if(library.serverTimestamp != NULL && [library.serverTimestamp compare: library.serverTimestamp] == NSOrderedAscending){
            [self _markLibraryAsFullyCachedAndCleanUp:libraryID];
        }
    }
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:ZPNOTIFICATION_ITEMS_AVAILABLE
     object:allItems];

    [[NSNotificationCenter defaultCenter]
     postNotificationName:ZPNOTIFICATION_ATTACHMENTS_AVAILABLE
     object:attachments];

    
    [self _checkMetadataQueue];
    

}

+(void) processNewLibrariesFromServer:(NSArray*)libraries{
    
        
    NSEnumerator* e = [libraries objectEnumerator];
    
    ZPZoteroLibrary* library;
    
    while ( library = (ZPZoteroLibrary*) [e nextObject]) {
        [ZPServerConnection retrieveCollectionsForLibraryFromServer:library.libraryID];
    }

    [ZPDatabase writeLibraries:libraries];
    
    while ( library = (ZPZoteroLibrary*) [e nextObject]) {
        if([ZPPreferences cacheMetadataAllLibraries]){
            [self _checkIfLibraryNeedsCacheRefreshAndQueue:library.libraryID];
        }
        
    }
    [self _checkMetadataQueue];

}
+(void) processNewCollectionsFromServer:(NSArray*)collections forLibraryID:(NSInteger)libraryID;{
    
    ZPZoteroLibrary* library = [ZPZoteroLibrary libraryWithID:libraryID];
    [ZPDatabase writeCollections:collections toLibrary:library];
    DDLogCVerbose(@"Collections available for library %i", libraryID);
    [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_LIBRARY_WITH_COLLECTIONS_AVAILABLE object:library];
    [self _checkMetadataQueue];

    
}

/*

 Processes a list containing all keys in a library
 
 */

+(void) processNewItemKeyListFromServer:(NSArray*)serverKeys forLibraryID:(NSInteger) libraryID{

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
            [self _addToItemQueue:nonExistingKeys libraryID:libraryID priority:FALSE];
            DDLogVerbose(@"Added %i non-existing keys from library %i that need data",[nonExistingKeys count],libraryID);
        }
        
        // Then add the rest of the items
        NSMutableArray* existingKeys = [NSMutableArray arrayWithArray:itemKeysThatNeedToBeRetrieved];
        [existingKeys removeObjectsInArray:nonExistingKeys];
        if([existingKeys count]>0){
            [self _addToItemQueue:existingKeys libraryID:libraryID priority:FALSE];
            DDLogVerbose(@"Added %i existing keys from library %i that might need new data",[existingKeys count],libraryID);
        }
        
    }

    [self _checkMetadataQueue];

}
+(void) processNewTopLevelItemKeyListFromServer:(NSArray*)itemKeys userInfo:(NSDictionary*)parameters{

    NSString* collectionKey = [parameters objectForKey:ZPKEY_COLLECTION_KEY];
    NSInteger libraryID = [[parameters objectForKey:ZPKEY_LIBRARY_ID] integerValue];

    DDLogVerbose(@"Received %i item keys for library %i and collection %@",[itemKeys count],libraryID,collectionKey);

    //Update collection memberships
    NSArray* tags = [parameters objectForKey:ZPKEY_TAG];
    NSString* searchString = [parameters objectForKey: ZPKEY_SEARCH_STRING];
    
    if(collectionKey!=NULL && searchString == NULL && (tags == NULL || [tags count]==0)){
        NSArray* cachedKeys = [ZPDatabase getItemKeysForLibrary:libraryID collectionKey:collectionKey searchString:NULL tags:NULL orderField:NULL sortDescending:FALSE];
        
        NSMutableArray* uncachedItems = [NSMutableArray arrayWithArray:itemKeys];
        [uncachedItems removeObjectsInArray:cachedKeys];
        
        if([uncachedItems count]>0) [ZPDatabase addItemKeys:uncachedItems toCollection:collectionKey];
        if([itemKeys count] >0) [ZPDatabase removeItemKeysNotInArray:itemKeys fromCollection:collectionKey];
    }

    // Do all the items exist in the cache?
    
    NSArray* cachedKeys = [ZPDatabase getItemKeysForLibrary:libraryID collectionKey:collectionKey searchString:searchString tags:tags orderField:NULL sortDescending:FALSE];
    NSMutableArray* uncachedItems = [NSMutableArray arrayWithArray:itemKeys];
    [uncachedItems removeObjectsInArray:cachedKeys];

    //If we have some of the items are in the cache but others are not, it is possible that the library cache is not up to date
    if([uncachedItems count]>0){
//        DDLogInfo(@"Zotero server returned item keys that are not in cache. Starting to refresh %@",[ZPZoteroLibrary libraryWithID:libraryID].title);
        [self _checkIfLibraryNeedsCacheRefreshAndQueue:libraryID];
    }

    [[NSNotificationCenter defaultCenter]
     postNotificationName:ZPNOTIFICATION_ITEM_LIST_AVAILABLE
     object:itemKeys
     userInfo:parameters];
    
    [self _checkMetadataQueue];
}

/*
 Compares a timestamp agains cached timestamp and stars retrieving data if needed
 */
+(void) processNewTimeStampForLibrary:(NSInteger)libraryID collection:(NSString*)collectionKey timestampValue:(NSString*)newTimestamp{

    // Sanity checking
    if(newTimestamp == nil) return;
    
    // Library timestamp
    
    if(collectionKey==NULL){
        //Check that we are not already cacheing this item.

        NSNumber* keyObj = [NSNumber numberWithInt:libraryID];
        NSString* currentTimestamp = [_libraryTimestamps objectForKey:keyObj];
        
        if(currentTimestamp == NULL || ! [currentTimestamp isEqualToString:newTimestamp]){
        
            [_libraryTimestamps setObject:newTimestamp forKey:keyObj];
   
            DDLogVerbose(@"Checking if we need to cache library %i",libraryID);
            [ZPServerConnection retrieveAllItemKeysFromLibrary:libraryID];
        
            
            //Retrieve collections
            
            ZPZoteroLibrary* container = (ZPZoteroLibrary*) [ZPZoteroLibrary libraryWithID:libraryID];
            
            if(![newTimestamp isEqualToString:container.cacheTimestamp]){
                
                [self _addToLibrariesQueue:container priority:FALSE];
                
                //Retrieve all collections for this library and add them to cache
                for(ZPZoteroCollection* collection in [ZPDatabase collectionsForLibrary:container.libraryID]){
                    [ZPServerConnection retrieveTimestampForLibrary:libraryID collection:collection.key];
                }
            }

        }        
    }
    
    //Collection timestamp
    
    else{
        ZPZoteroCollection* collection = [ZPZoteroCollection collectionWithKey:collectionKey];
        if(![newTimestamp isEqualToString:collection.cacheTimestamp]){
            [ZPServerConnection retrieveKeysInLibrary:libraryID collection:collectionKey];
            [ZPDatabase setUpdatedTimestampForCollection:collectionKey toValue:newTimestamp];
        }
    }
    
    [self _checkMetadataQueue];
}


#pragma mark -
#pragma mark Notifier methods for metadata

+(void) notifyActiveItemChanged:(NSNotification *) notification{
    [ZPServerConnection retrieveSingleItemAndChildrenWithKey:notification.object];
}

+(void) notifyActiveCollectionChanged:(NSNotification *) notification{
    
    if(notification.object != NULL){
        [self _checkIfCollectionNeedsCacheRefreshAndQueue:notification.object];
    }
}
+(void) notifyActiveLibraryChanged:(NSNotification *) notification{

    _activelibraryID = [(NSNumber*) notification.object integerValue];
    
    // Retrieve the collections so that they are refreshed always when a new library is chosen
    [ZPServerConnection retrieveCollectionsForLibraryFromServer:_activelibraryID];

    // Check if this library needs a cache refresh for the items
    [self _checkIfLibraryNeedsCacheRefreshAndQueue:_activelibraryID];
}


+(void) notifyLibraryWithCollectionsAvailable:(NSNotification*) notification{
    if([ZPPreferences cacheMetadataAllLibraries]){
        [self _checkIfLibraryNeedsCacheRefreshAndQueue:[(ZPZoteroLibrary*)notification.object libraryID]];
    }
}

+(void) notifyAuthenticationSuccesful:(NSNotification*) notification{
    [ZPServerConnection retrieveLibrariesFromServer];
}

+(void) notifyUserInterfaceAvailable:(NSNotification*)notification{
    [ZPServerConnection retrieveLibrariesFromServer];
}



@end
