//
//  ZPCache.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
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


#import "ZPCacheController.h"
#import "ZPPreferences.h"
#import "ZPDataLayer.h"
#import "ZPDatabase.h"
#import "ZPServerResponseXMLParser.h"
#import "ZPServerConnection.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroAttachment.h"
#import "ZPZoteroNote.h"
#import "ZPLogger.h"

#define NUMBER_OF_ITEMS_TO_RETRIEVE 50


@interface ZPCacheController (){
    NSNumber* _activelibraryID;
    NSString* _activeCollectionKey;
    NSString* _activeItemKey;
}

-(void) _checkQueues;
-(void) _checkMetadataQueue;
-(void) _checkDownloadQueue;
-(void) _doItemRetrieval:(NSArray*) itemKeys fromLibrary:(NSNumber*)libraryID;

-(void) _cacheItemsAndAttachToParentsIfNeeded:(NSArray*) items;
//-(void) _attachChildItemsToParents:(NSArray*) items;

//Gets one item details and writes these to the database
-(void) _updateItemDetailsFromServer:(ZPZoteroItem*) item;

-(void) _checkIfLibraryNeedsCacheRefreshAndQueue:(NSNumber*) libraryID;
-(void) _checkIfCollectionNeedsCacheRefreshAndQueue:(NSString*)collectionKey;
-(void) _checkIfAttachmentExistsAndQueueForDownload:(ZPZoteroAttachment*)attachment;

//TODO: refactor this method
-(void) _checkIfAttachmenstExistAndQueueForDownload:(NSArray*)parentKeys;

- (unsigned long long int) _documentsFolderSize;
- (void) _scanAndSetSizeOfDocumentsFolder;
- (void) _updateCacheSizePreference;
- (void) _cleanUpCache;
- (void) _updateCacheSizeAfterAddingAttachment:(ZPZoteroAttachment*)attachment;

-(void) _updateCollectionsForLibraryFromServer:(ZPZoteroLibrary*) libraryID;

@end

@implementation ZPCacheController


static ZPCacheController* _instance = nil;


-(id)init
{
    self = [super init];
    
    
    //Initialize OperationQueues for retrieving data from server and writing it to cache
    _serverRequestQueue = [[NSOperationQueue alloc] init];
    [_serverRequestQueue setMaxConcurrentOperationCount:4];

    _fileDownloadQueue  = [[NSOperationQueue alloc] init];
    [_fileDownloadQueue  setMaxConcurrentOperationCount:2];
    
    //These collections contain things that we need to cache. These have been checked so that we know that they are either missing or outdated
    
    _itemKeysToRetrieve = [[NSMutableDictionary alloc] init];
    _libraryTimestamps = [[NSMutableDictionary alloc] init];

    _librariesToCache = [[NSMutableArray alloc] init];
    _collectionsToCache = [[NSMutableArray alloc] init];
    _filesToDownload = [[NSMutableArray alloc] init];
    
    //Register as observer so that we can follow the size of the cache
    [[ZPDataLayer instance] registerAttachmentObserver:self];
    
    _sizeOfDocumentsFolder = 0;
    [self performSelectorInBackground:@selector(_scanAndSetSizeOfDocumentsFolder) withObject:NULL];
	
    
    return self;
}

/*
 Singleton accessor
 */

+(ZPCacheController*) instance {
    if(_instance == NULL){
        _instance = [[ZPCacheController alloc] init];
    }
    return _instance;
}

-(void) activate{
    
    [[ZPDataLayer instance] registerLibraryObserver:self];
    [self performSelectorInBackground:@selector(updateLibrariesAndCollectionsFromServer) withObject:NULL];

}

/*
 
 Checks if there are things to cache and starts processing these if there is something to retrieve.
 
*/

-(void) _checkQueues{

    [self _checkDownloadQueue];
    [self _checkMetadataQueue];
}

-(void) _checkDownloadQueue{
    @synchronized(_filesToDownload){
        //Only cache up to 95% full
        while([_fileDownloadQueue operationCount] < [_fileDownloadQueue maxConcurrentOperationCount] && [_filesToDownload count] >0 && _sizeOfDocumentsFolder < 0.95*[[ZPPreferences instance] maxCacheSize]){
            ZPZoteroAttachment* attachment = [_filesToDownload objectAtIndex:0];
            [_filesToDownload removeObjectAtIndex:0];
//            NSLog(@"Queueing download %@ Files in queue %i", attachment.attachmentTitle ,[_filesToDownload count]);
            NSOperation* downloadOperation = [[NSInvocationOperation alloc] initWithTarget:[ZPServerConnection instance] selector:@selector(downloadAttachment:) object:attachment];
            
            [_fileDownloadQueue addOperation:downloadOperation];
        }        
    }
    
}

-(void) _checkMetadataQueue{
    
    @synchronized(_serverRequestQueue){
        while([_serverRequestQueue operationCount] <= [_serverRequestQueue maxConcurrentOperationCount]){
            
            @synchronized(_librariesToCache){
                if([_librariesToCache count]>0){
                    
                    NSOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_doContainerRetrieval:) object:[_librariesToCache lastObject]];
                    
                    //Remove the items that we are retrieving
                    [_librariesToCache removeLastObject];
                    
                    [_serverRequestQueue addOperation:retrieveOperation];
                    NSLog(@"Started Library retrieval operation. Operations in queue is %i. Number of libraries in queue is %i",[_serverRequestQueue operationCount],[_librariesToCache count]);
                    
                } 
            }
            //Choose the queue the active library or choose a first non-empty queue
            
            @synchronized(_itemKeysToRetrieve){
                NSMutableArray* keyArray = [_itemKeysToRetrieve objectForKey:_activelibraryID];
                NSEnumerator* e = [_itemKeysToRetrieve keyEnumerator];
                NSNumber* libraryID = _activelibraryID;
                
                while((keyArray == NULL || [keyArray count]==0) && (libraryID = [e nextObject])) keyArray = [_itemKeysToRetrieve objectForKey:keyArray];
                
                //If we found a non-empty que, queue item retrival
                if(keyArray != NULL && [keyArray count]>0){
                    NSArray* keysToRetrieve;
                    @synchronized(keyArray){
                        NSRange range = NSMakeRange(0, MIN(NUMBER_OF_ITEMS_TO_RETRIEVE,[keyArray count]));
                        keysToRetrieve = [keyArray subarrayWithRange:range];
                        
                        //Remove the items that we are retrieving
                        [keyArray removeObjectsInRange:range];
                        
                        //If the array became empty, mark this library as completely cached
                        if([keyArray count]==0){
                            NSString* timestamp = [_libraryTimestamps objectForKey:libraryID];
                            if(timestamp!=NULL){
                                //Update both the DB and the in-memory cache.
                                [[ZPDatabase instance] setUpdatedTimestampForLibrary:libraryID toValue:timestamp];
                                [[ZPZoteroLibrary dataObjectWithKey:libraryID] setCacheTimestamp:timestamp];
                                NSLog(@"Library %@ is now fully cached", libraryID);
                                [_libraryTimestamps removeObjectForKey:libraryID];
                            }
                        }
                        
                    }
                    
                    //Create an invocation
                    SEL selector = @selector(_doItemRetrieval:fromLibrary:);
                    NSMethodSignature* signature = [[self class] instanceMethodSignatureForSelector:selector];
                    NSInvocation* invocation  = [NSInvocation invocationWithMethodSignature:signature];
                    [invocation setTarget:self];
                    [invocation setSelector:selector];
                    
                    //Set arguments
                    [invocation setArgument:&keysToRetrieve atIndex:2];
                    [invocation setArgument:&libraryID atIndex:3];
                    
                    //Create operation and queue it for background retrieval
                    NSOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithInvocation:invocation];
                    [_serverRequestQueue addOperation:retrieveOperation];
                    NSLog(@"Started item retrieval operation. Operations in queue is %i. Number of items in queue for library %@ is %i",[_serverRequestQueue operationCount],libraryID,[keyArray count]);
                    
                }
                
            }

            // Last, check collection memberships
            @synchronized(_collectionsToCache){
                
                if([_collectionsToCache count]>0){
                    
                    NSOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_doContainerRetrieval:) object:[_collectionsToCache lastObject]];
                    
                    //Remove the items that we are retrieving
                    [_collectionsToCache removeLastObject];
                    
                    [_serverRequestQueue addOperation:retrieveOperation];
                    NSLog(@"Started collection retrieval operation. Operations in queue is %i. Number of collections in queue is %i",[_serverRequestQueue operationCount],[_collectionsToCache count]);
                    
                } 
                else break;
            }
        }
    }
}


- (void) _doItemRetrieval:(NSArray*) itemKeys fromLibrary:(NSNumber*)libraryID{
    
    NSLog(@"Retrieving items %@",[itemKeys componentsJoinedByString:@", "]);
    
    
    NSArray* items = [[ZPServerConnection instance] retrieveItemsFromLibrary:libraryID itemKeys:itemKeys];
        
    [self _cacheItemsAndAttachToParentsIfNeeded:items];

    //Perform checking the queue in another thread so that the current operation can exit
    NSLog(@"Rechecking queues");
    [self performSelectorInBackground:@selector(_checkQueues) withObject:NULL];
}


-(void) _cacheItemsAndAttachToParentsIfNeeded:(NSArray*) items{
    
    NSLog(@"Writing %i items to cache",[items count]);
           
    ZPZoteroItem* item;

    NSMutableArray* normalItems = [NSMutableArray array];
    NSMutableArray* standaloneNotesAndAttachments = [NSMutableArray array];
    NSMutableArray* attachments = [NSMutableArray array];
    NSMutableArray* notes = [NSMutableArray array];
    NSMutableArray* parentItemsForAttachments = [NSMutableArray array];
    NSMutableArray* parentItemsForNotes = [NSMutableArray array];
    
    for(item in items){
        if( [item needsToBeWrittenToCache]){

            if([item isKindOfClass:[ZPZoteroAttachment class]]){       
                ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) item;

                [attachments addObject:attachment];
                [self _checkIfAttachmentExistsAndQueueForDownload:attachment];
                
                //Standalone attachments
                if(attachment.parentItemKey==attachment.key){
                    [standaloneNotesAndAttachments addObject:attachment];
                }
                else{
                    ZPZoteroItem* parent = (ZPZoteroItem*) [ZPZoteroItem dataObjectWithKey:attachment.parentItemKey];
                    if(![parentItemsForAttachments containsObject:parent]) [parentItemsForAttachments addObject:parent];
                }
                
            }
            //If this is a note item, store the note information
            else if([item isKindOfClass:[ZPZoteroNote class]]){
                ZPZoteroNote* note = (ZPZoteroNote*) item;
                [notes addObject:note];
                
                //Standalone notes
                if(note.parentItemKey==note.key){
                    [standaloneNotesAndAttachments addObject:note];
                }
                else{
                    ZPZoteroItem* parent = (ZPZoteroItem*) [ZPZoteroItem dataObjectWithKey:note.parentItemKey];
                    if(![parentItemsForNotes containsObject:parent]) [parentItemsForNotes addObject:parent];
                }

                
            }
            //Normal item
            else{
                [normalItems addObject:item];
            }
        }
    }
    
    NSArray* topLevelItemsThatWereWrittenToCache = [[ZPDatabase instance] writeItems:[normalItems arrayByAddingObjectsFromArray:standaloneNotesAndAttachments]];

    [[ZPDatabase instance] writeAttachments:attachments];
    [[ZPDatabase instance] writeNotes:notes];
    
    NSMutableArray* itemsThatNeedCreatorsAndFields = [NSMutableArray arrayWithArray:topLevelItemsThatWereWrittenToCache];
    [itemsThatNeedCreatorsAndFields removeObjectsInArray:standaloneNotesAndAttachments];
                            
    [[ZPDatabase instance] writeItemsFields:itemsThatNeedCreatorsAndFields];
    [[ZPDatabase instance] writeItemsCreators:itemsThatNeedCreatorsAndFields];

    //Refresh the attachments for those items that got new attachments
    for(item in parentItemsForAttachments){
        [[ZPDatabase instance] addAttachmentsToItem:item];
    }
    for(item in parentItemsForNotes){
        [[ZPDatabase instance] addNotesToItem:item];
    }
    
    [[ZPDataLayer instance] performSelectorInBackground:@selector(notifyItemsAvailable:)
                                              withObject:[[topLevelItemsThatWereWrittenToCache arrayByAddingObjectsFromArray:parentItemsForNotes]arrayByAddingObjectsFromArray:parentItemsForAttachments]];
    
}

/*
 
 Retrieves container memberships. This does not automatically queue items retrievals because
 all items will be retieved for libraries anyway based on the date modified.
 
 */

- (void) _doContainerRetrieval:(NSObject*) container{
    
    //Is it a library or a collection
    NSString* collectionKey = NULL;
    NSNumber* libraryID = NULL;
    if([container isKindOfClass:[ZPZoteroLibrary class]]){
        libraryID = [(ZPZoteroLibrary*)container libraryID];
    }
    else{
        libraryID = [(ZPZoteroCollection*)container libraryID];
        collectionKey = [(ZPZoteroCollection*)container collectionKey];
    }
    
    NSString* newTimestamp = [[ZPServerConnection instance] retrieveTimestampForContainer:libraryID collectionKey:collectionKey];

    if(collectionKey==NULL){
        //Check that we are not already cacheing this item.
        if([_libraryTimestamps objectForKey:libraryID]==NULL){
            [_libraryTimestamps setObject:newTimestamp forKey:libraryID];
            NSLog(@"Checking if we need to cache library %@",libraryID);
            NSArray* serverKeys = [[ZPServerConnection instance] retrieveAllItemKeysFromLibrary:libraryID];
            
            [[ZPDatabase instance] deleteItemKeysNotInArray:serverKeys fromLibrary:libraryID]; 
            
            //If there is data in the library, start cacheing it
            
            if([serverKeys count]>0){
                //Get all keys in the library
                NSArray* cacheKeys = [[ZPDatabase instance] getAllItemKeysForLibrary:libraryID];
                
                NSString* markerKey = [[ZPDatabase instance] getFirstItemKeyWithTimestamp:[(ZPZoteroLibrary*)container cacheTimestamp] from:libraryID];
                
                //Iterate the arrays backward until we find a difference
                
                NSInteger index = [serverKeys indexOfObject:markerKey];
                
                //Sanity check
                if(index == NSNotFound){
                    index = [serverKeys count]-1;
                }
                
                NSArray* itemKeysThatNeedToBeRetrieved = [serverKeys subarrayWithRange:NSMakeRange(0, index)];
                
                /*
                 Old check. Do not remove. 
                 
                 NSInteger index;
                 
                 for(index=0; index < [serverKeys count]; index++){
                 
                 if(index >=[cacheKeys count]) break;
                 
                 NSString* serverKey = [serverKeys objectAtIndex:[serverKeys count]-index-1];
                 NSString* cacheKey = [cacheKeys objectAtIndex:[cacheKeys count]-index-1];
                 
                 if(![serverKey isEqualToString:cacheKey]) break;
                 }
                 
                 NSLog(@"Adding items to queue up to last %i",index);
                 
                 // Queue all the items that were different
                 NSArray* itemKeysThatNeedToBeRetrieved = [serverKeys subarrayWithRange:NSMakeRange(0, [serverKeys count]-index-1)];
                 
                 */
                
                
                // First add all items that do not exist in the cache
                NSMutableArray* nonExistingKeys = [NSMutableArray arrayWithArray:itemKeysThatNeedToBeRetrieved];
                [nonExistingKeys removeObjectsInArray:cacheKeys];
                if([nonExistingKeys count]>0){
                    [self addToItemQueue:nonExistingKeys libraryID:libraryID priority:FALSE];
                    NSLog(@"Added %i non-existing keys that need data",[nonExistingKeys count]);
                }
                
                // Then add the rest of the items
                NSMutableArray* existingKeys = [NSMutableArray arrayWithArray:itemKeysThatNeedToBeRetrieved];
                [existingKeys removeObjectsInArray:nonExistingKeys];
                if([existingKeys count]>0){
                    [self addToItemQueue:existingKeys libraryID:libraryID priority:FALSE];   
                    NSLog(@"Added %i existing keys that might need new data",[existingKeys count]);
                }
                
            }            
        }        
    }
    else{
        NSArray* itemKeys = [[ZPServerConnection instance] retrieveKeysInContainer:libraryID collectionKey:collectionKey];

        NSArray* cachedKeys = [[ZPDatabase instance] getItemKeysForLibrary:libraryID collectionKey:collectionKey searchString:NULL orderField:NULL sortDescending:FALSE];
        
        NSMutableArray* uncachedItems = [NSMutableArray arrayWithArray:itemKeys];
        [uncachedItems removeObjectsInArray:cachedKeys];
        
        if([uncachedItems count]>0) [[ZPDatabase instance] addItemKeys:uncachedItems toCollection:collectionKey];
        if([itemKeys count] >0) [[ZPDatabase instance] removeItemKeysNotInArray:itemKeys fromCollection:collectionKey]; 
        [[ZPDatabase instance] setUpdatedTimestampForCollection:collectionKey toValue:newTimestamp];
    }

    [self performSelectorInBackground:@selector(_checkQueues) withObject:NULL];
}

-(void) refreshActiveItem:(ZPZoteroItem*) item {
    if(item == NULL) [NSException raise:@"Item cannot be null" format:@"Method refresh active item was called with an argument that was null."];
    [self performSelectorInBackground:@selector(_updateItemDetailsFromServer:) withObject:item];
    
}

-(void) _updateItemDetailsFromServer:(ZPZoteroItem*)item{

    if(item == NULL) [NSException raise:@"Item cannot be null" format:@"Method _updateItemDetailsFromServer was called with an argument that was null."];

    _activeItemKey = item.key;
    
    item = [[ZPServerConnection instance] retrieveSingleItemDetailsFromServer:item];
    NSMutableArray* items = [NSMutableArray arrayWithObject:item];
    [items addObjectsFromArray:item.attachments];
    [items addObjectsFromArray:item.notes];
    
    [self _cacheItemsAndAttachToParentsIfNeeded:items];

    //The method call above will only fire a notification if the item was actually updated. Fire it here again so that we will always get a notification and know that the item has been updated.
    [[ZPDataLayer instance] notifyItemsAvailable:[NSArray arrayWithObject:item]];
       
}

-(void) setActiveLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey{

    if(! [libraryID isEqual:_activelibraryID] && ! [[ZPPreferences instance] cacheAttachmentsAllLibraries] ){
        @synchronized(_filesToDownload){
            [_filesToDownload removeAllObjects];
        }
//        NSLog(@"Clearing attachment download queue because library changed and preferences do not indicate that all libraries should be downloaded");
    }
    
    //Store the libraryID and collectionKEy
    _activelibraryID = libraryID;
    
    //Both keys might be null, so we need to compare equality directly as well
    if(! (collectionKey == _activeCollectionKey || [collectionKey isEqual:_activeCollectionKey]) && ! [[ZPPreferences instance] cacheAttachmentsActiveLibrary]){
        @synchronized(_filesToDownload){

            [_filesToDownload removeAllObjects];
        }
//        NSLog(@"Clearing attachment download queue because collection changed and preferences do not indicate that all collections should be downloaded");
    }
    _activeCollectionKey = collectionKey;
    
    //Add attachments to queue
    NSArray* itemKeysToCheck = [[ZPDatabase instance] getItemKeysForLibrary:libraryID collectionKey:collectionKey searchString:NULL orderField:NULL sortDescending:FALSE];
    [self performSelectorInBackground:@selector(_checkIfAttachmenstExistAndQueueForDownload:) withObject:itemKeysToCheck];
    
    //Check if the container needs a refresh
    if(collectionKey == NULL){
        [self performSelectorInBackground:@selector(_checkIfLibraryNeedsCacheRefreshAndQueue:) withObject:libraryID];   
    }
    else{
        [self performSelectorInBackground:@selector(_checkIfCollectionNeedsCacheRefreshAndQueue:) withObject:collectionKey];
    }
    
}

-(void) _checkIfAttachmenstExistAndQueueForDownload:(NSArray*)parentKeys{

    for(NSString* key in parentKeys){
        ZPZoteroItem* item = (ZPZoteroItem*) [ZPZoteroItem dataObjectWithKey:key];
        for(ZPZoteroAttachment* attachment in item.attachments){
            [self _checkIfAttachmentExistsAndQueueForDownload:attachment];
        }    
    }
}

-(void) _checkIfAttachmentExistsAndQueueForDownload:(ZPZoteroAttachment*)attachment{
    
    if(! attachment.fileExists){
        BOOL doCache=false;
        //Cache based on preferences
        if([[ZPPreferences instance] cacheAttachmentsAllLibraries]){
            doCache = true;
        }
        else if([[ZPPreferences instance] cacheAttachmentsActiveLibrary]){
            doCache = (attachment.libraryID == _activelibraryID);
            
        }
        //Check if the parent belongs to active the collection
        else if([[ZPPreferences instance] cacheAttachmentsActiveCollection]){
            ZPZoteroItem* parent = (ZPZoteroItem*)[ZPZoteroItem dataObjectWithKey:attachment.parentItemKey];
            if([parent.libraryID isEqualToNumber:_activelibraryID] && _activeCollectionKey == NULL){
                doCache=true;
            }
            else if([parent.collections containsObject:[ZPZoteroCollection dataObjectWithKey:_activeCollectionKey] ]){
                doCache = true;
            }
        }
        else if([[ZPPreferences instance] cacheAttachmentsActiveItem]){
            doCache =( attachment.parentItemKey == _activeItemKey);
        }
        
        if(doCache){
            @synchronized(_filesToDownload){

                [_filesToDownload removeObject:attachment];
                [_filesToDownload insertObject:attachment atIndex:0];
                //            NSLog(@"Queuing attachment download to %@, number of files in queue %i",attachment.fileSystemPath,[_filesToDownload count]);
            }
            [self _checkQueues];
        }
    }
}

-(void) addToLibrariesQueue:(ZPZoteroLibrary*)object priority:(BOOL)priority{
    //Check this library is already baing cached
    if([_libraryTimestamps objectForKey:object.libraryID] == NULL){
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

-(void) addToItemQueue:(NSArray*)itemKeys libraryID:(NSNumber*)libraryID priority:(BOOL)priority{

    @synchronized(_itemKeysToRetrieve){
        NSMutableArray* targetArray = [_itemKeysToRetrieve objectForKey:libraryID];
        if(targetArray == NULL){
            targetArray = [NSMutableArray array];
            [_itemKeysToRetrieve setObject:targetArray forKey:libraryID];               
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

-(void) _checkIfLibraryNeedsCacheRefreshAndQueue:(NSNumber*) libraryID{
   
    NSString* timestamp = [[ZPServerConnection instance] retrieveTimestampForContainer:libraryID collectionKey:NULL];
    
    
    if(timestamp != NULL){
        
        ZPZoteroLibrary* container = (ZPZoteroLibrary*) [ZPZoteroLibrary dataObjectWithKey:libraryID];
        
        if(![timestamp isEqualToString:container.cacheTimestamp]){
            
            [self addToLibrariesQueue:container priority:FALSE];
            [self _checkQueues];

            if([[ZPPreferences instance] cacheMetadataActiveLibrary]){
                
                //Retrieve all collections for this library and add them to cache
                for(ZPZoteroCollection* collection in [[ZPDatabase instance] collectionsForLibrary:container.libraryID]){
                    
                    timestamp = [[ZPServerConnection instance] retrieveTimestampForContainer:libraryID collectionKey:collection.collectionKey];
                    
                    if(timestamp != NULL){
                        
                        if(![timestamp isEqualToString:collection.cacheTimestamp]){
                                                        
                            [self addToCollectionsQueue:collection priority:FALSE];
                            [self _checkQueues];

                        }
                    }
                    
                }
            }
        }
    }
}

-(void) _checkIfCollectionNeedsCacheRefreshAndQueue:(NSString*)collectionKey{
 
    ZPZoteroCollection* container = (ZPZoteroCollection*) [ZPZoteroCollection dataObjectWithKey:collectionKey];
    NSNumber* libraryID = container.libraryID;
    
    if(libraryID == NULL) [NSException raise:@"libraryID for collection object was null" format:@"This should not happen"];
    
    //Get the time stamp to see if we need to retrieve more
    
    NSString* timestamp = [[ZPServerConnection instance] retrieveTimestampForContainer:libraryID collectionKey:collectionKey];

    
    if(timestamp != NULL){
        
        if(![timestamp isEqualToString:container.cacheTimestamp]){
            
            //If a Collection needs to be cached, check if a library needs cache as well.
            [self _checkIfLibraryNeedsCacheRefreshAndQueue:libraryID];
        
            [self addToCollectionsQueue:container priority:FALSE];

            [self _checkQueues];
        }
    }
}

    
-(void) updateLibrariesAndCollectionsFromServer{

    //My library  
    [self performSelectorInBackground:@selector(_updateCollectionsForLibraryFromServer:) withObject:[ZPZoteroLibrary dataObjectWithKey:[NSNumber numberWithInt:1]]];

    NSLog(@"Loading group library information from server");
    NSArray* libraries = [[ZPServerConnection instance] retrieveLibrariesFromServer];

    if(libraries!=NULL){
        
        NSEnumerator* e = [libraries objectEnumerator];
        
        ZPZoteroLibrary* library;
        
        while ( library = (ZPZoteroLibrary*) [e nextObject]) {
            
            [self performSelectorInBackground:@selector(_updateCollectionsForLibraryFromServer:) withObject:library];
            
        }
        [[ZPDatabase instance] writeLibraries:libraries];
    }    
}

-(void) _updateCollectionsForLibraryFromServer:(ZPZoteroLibrary*) library{
    NSLog(@"Loading collections for library %@",library.libraryID);
    
    NSArray* collections = [[ZPServerConnection instance] retrieveCollectionsForLibraryFromServer:library.libraryID];
    if(collections!=NULL){
        [[ZPDatabase instance] writeCollections:collections toLibrary:library];
        [[ZPDataLayer instance] notifyLibraryWithCollectionsAvailable:library];
    }

}




-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library{
    if([[ZPPreferences instance] cacheMetadataAllLibraries]){
        [self _checkIfLibraryNeedsCacheRefreshAndQueue:library.libraryID];
        [self _checkQueues];
    }
}




#pragma mark -
#pragma mark Attachment cache


-(void) notifyAttachmentDownloadCompleted:(ZPZoteroAttachment*) attachment{
    [self _updateCacheSizeAfterAddingAttachment:attachment];
    [self _checkQueues];
}

- (void) purgeAllAttachmentFilesFromCache{
    
    NSString* _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_documentsDirectory error:NULL];
    
    for (NSString* _documentFilePath in directoryContent) {
        if(! [@"zotpad.sqlite" isEqualToString: _documentFilePath]){
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
    if(_sizeOfDocumentsFolder < 1073741824){
        NSInteger temp = _sizeOfDocumentsFolder/1048576;
        [[ZPPreferences instance] setCurrentCacheSize:[NSString stringWithFormat:@"%i MB",temp]];
        
    }
    else{
        float temp = ((float)_sizeOfDocumentsFolder)/1073741824;
        [[ZPPreferences instance] setCurrentCacheSize:[NSString stringWithFormat:@"%.1f GB",temp]];
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
        NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:[_documentsDirectory stringByAppendingPathComponent:_documentFilePath] traverseLink:YES];
        _documentsFolderSize += [_documentFileAttributes fileSize];
    }
    
    return _documentsFolderSize;
}

- (void) _updateCacheSizeAfterAddingAttachment:(ZPZoteroAttachment*)attachment{
    if(_sizeOfDocumentsFolder!=0){
        
        _sizeOfDocumentsFolder = _sizeOfDocumentsFolder + attachment.attachmentLength;

//        NSLog(@"Cache size after adding %@ to cache is %i",attachment.fileSystemPath,_sizeOfDocumentsFolder);

        if(_sizeOfDocumentsFolder>=[[ZPPreferences instance] maxCacheSize]) [self _cleanUpCache];
        [self _updateCacheSizePreference];
    }
}

- (void) _cleanUpCache{
    
    NSArray* paths = [[ZPDatabase instance] getCachedAttachmentsOrderedByRemovalPriority];

    //Delete orphaned files
    
    NSString* _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_documentsDirectory error:NULL];
    
    
    for (NSString* _documentFilePath in directoryContent) {
        NSString* path = [_documentsDirectory stringByAppendingPathComponent:_documentFilePath];

        if(![paths containsObject:path] && ! [path hasSuffix:@"zotpad.sqlite"] && ! [path hasSuffix:@"zotpad.sqlite-journal"]){
            NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES];
            _sizeOfDocumentsFolder -= [_documentFileAttributes fileSize];
            NSLog(@"Deleting orphaned file %@ cache size now %i",path,_sizeOfDocumentsFolder);
            [[NSFileManager defaultManager] removeItemAtPath:path error: NULL];
        }
    }
    
    //Delete attachment files until the size of the cache is below the maximum size
    NSString* path;
    for(path in paths){
        NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES];
        _sizeOfDocumentsFolder -= [_documentFileAttributes fileSize];
        [[NSFileManager defaultManager] removeItemAtPath:path error: NULL];
        NSLog(@"Deleting old file to reclaim space %@ cache size now %i",path,_sizeOfDocumentsFolder);
        if (_sizeOfDocumentsFolder<=[[ZPPreferences instance] maxCacheSize]) break;
    }

}


@end
