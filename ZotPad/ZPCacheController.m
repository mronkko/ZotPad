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
#import "ZPDataLayer.h"
#import "ZPDatabase.h"
#import "ZPServerResponseXMLParser.h"
#import "ZPServerConnection.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroAttachment.h"
#import "ZPZoteroNote.h"

#define NUMBER_OF_ITEMS_TO_RETRIEVE 50


@interface ZPCacheController (){
    NSNumber* _activelibraryID;
    NSString* _activeCollectionKey;
    NSString* _activeItemKey;
    
    //Variables indicating if we are currently refreshing lobraries and collectiosn from server
    BOOL _isRefresingLibraries;
    NSMutableSet* _librariesWhoseCollectionsAreBeingRefreshed;
}

-(void) _checkQueues;
-(void) _checkMetadataQueue;
-(void) _checkDownloadQueue;
-(void) _checkUploadQueue;

-(void) _scanFilesToUpload;

-(void) _doItemRetrieval:(NSArray*) itemKeys fromLibrary:(NSNumber*)libraryID;

-(void) _cacheItemsAndAttachToParentsIfNeeded:(NSArray*) items;
//-(void) _attachChildItemsToParents:(NSArray*) items;

//Gets one item details and writes these to the database
-(void) _updateItemDetailsFromServer:(ZPZoteroItem*) item;

-(void) _checkIfLibraryNeedsCacheRefreshAndQueue:(NSNumber*) libraryID;
-(void) _checkIfCollectionNeedsCacheRefreshAndQueue:(NSString*)collectionKey;
-(void) _checkIfAttachmentExistsAndQueueForDownload:(ZPZoteroAttachment*)attachment;

//TODO: refactor this method
-(void) _checkIfAttachmentsExistWithParentKeysAndQueueForDownload:(NSArray*)parentKeys;

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
    
    
    //Initialize OperationQueues for retrieving data from server and writing it to cache
    _serverRequestQueue = [[NSOperationQueue alloc] init];
    [_serverRequestQueue setMaxConcurrentOperationCount:4];
    
    //These collections contain things that we need to cache. These have been checked so that we know that they are either missing or outdated
    
    _itemKeysToRetrieve = [[NSMutableDictionary alloc] init];
    _libraryTimestamps = [[NSMutableDictionary alloc] init];

    _librariesToCache = [[NSMutableArray alloc] init];
    _collectionsToCache = [[NSMutableArray alloc] init];
    _filesToDownload = [[NSMutableArray alloc] init];
    _attachmentsToUpload = [[NSMutableSet alloc] init];
    
    //Register as observer so that we can follow the size of the cache
    [[ZPDataLayer instance] registerAttachmentObserver:self];
    
    //Observe new libraries so that we know to cache them
    [[ZPDataLayer instance] registerLibraryObserver:self];

    _sizeOfDocumentsFolder = 0;    [self performSelectorInBackground:@selector(_scanAndSetSizeOfDocumentsFolder) withObject:NULL];
	
    _isRefresingLibraries =FALSE;
    _librariesWhoseCollectionsAreBeingRefreshed = [[NSMutableSet alloc] init];

    [self performSelectorInBackground:@selector(updateLibrariesAndCollectionsFromServer) withObject:NULL];
    /*
    Start building cache immediately if the user has chosen to cache all libraries
     */
     
    if([[ZPPreferences instance] cacheAttachmentsAllLibraries] || [[ZPPreferences instance] cacheMetadataAllLibraries]){
        NSArray* libraries = [[ZPDatabase instance] libraries];
        
        ZPZoteroLibrary* library;
        for(library in libraries){
            if([[ZPPreferences instance] cacheAttachmentsAllLibraries]){
                //TODO: refactor so that this block is not needed
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{
                    NSArray* itemKeysToCheck = [[ZPDatabase instance] getItemKeysForLibrary:library.libraryID collectionKey:NULL searchString:NULL orderField:NULL sortDescending:FALSE];
                    [self _checkIfAttachmentsExistWithParentKeysAndQueueForDownload:itemKeysToCheck];
                });
            }
            if([[ZPPreferences instance] cacheMetadataAllLibraries]){
                [self performSelectorInBackground:@selector(_checkIfLibraryNeedsCacheRefreshAndQueue:) withObject:library.libraryID];   
            }
        }
    }
     
    [self performSelectorInBackground:@selector(_scanFilesToUpload) withObject:NULL];
     
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


-(void) setStatusView:(ZPCacheStatusToolbarController*) statusView{
    _statusView = statusView;
    
    NSInteger maxCacheSize = [[ZPPreferences instance] maxCacheSize];
    NSInteger cacheSizePercent = _sizeOfDocumentsFolder*100/ maxCacheSize;
    [_statusView setCacheUsed:cacheSizePercent];

}

/*
 
 Checks if there are things to cache and starts processing these if there is something to retrieve.
 
*/

-(void) _checkQueues{

    [self _checkDownloadQueue];
    [self _checkMetadataQueue];
    [self _checkUploadQueue];
}

-(void) _checkDownloadQueue{
    @synchronized(_filesToDownload){

        [_statusView setFileDownloads:[_filesToDownload count]];

//        DDLogVerbose(@"There are %i files in cache download queue",[_filesToDownload count]);

        if([_filesToDownload count]>0){
            //Only cache up to 95% full
            if(_sizeOfDocumentsFolder < 0.95*[[ZPPreferences instance] maxCacheSize]){
//                DDLogVerbose(@"There is space on device");
                if([ZPServerConnection instance] && [[ZPServerConnection instance] numberOfFilesDownloading] <1){
                    ZPZoteroAttachment* attachment = [_filesToDownload objectAtIndex:0];
                    [_filesToDownload removeObjectAtIndex:0];
                    while ( ![[ZPServerConnection instance] checkIfCanBeDownloadedAndStartDownloadingAttachment:attachment] && [_filesToDownload count] >0){
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
        
        DDLogVerbose(@"Checked upload queue: Files to upload %i",[_attachmentsToUpload count]);
        
        if([_attachmentsToUpload count]>0){
            if([ZPServerConnection instance] && [[ZPServerConnection instance] numberOfFilesUploading] <1){
                ZPZoteroAttachment* attachment = [_attachmentsToUpload anyObject];
                //Remove from queue and upload
                [_attachmentsToUpload removeObject:attachment];
                [[ZPServerConnection instance] uploadVersionOfAttachment:attachment];
                
            }
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
                    DDLogVerbose(@"Started Library retrieval operation. Operations in queue is %i. Number of libraries in queue is %i",[_serverRequestQueue operationCount],[_librariesToCache count]);
                    
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
                NSMutableArray* keyArray = [_itemKeysToRetrieve objectForKey:_activelibraryID];
                NSEnumerator* e = [_itemKeysToRetrieve keyEnumerator];
                NSNumber* libraryID = _activelibraryID;
            
                //If the active library does not have anything to retrieve, loop over all libraries to see if there is something to retrieve
                
                while(keyArray == NULL || [keyArray count]==0){
                    if( !( libraryID = [e nextObject])){
                        break;
                        
                    }
                    keyArray = [_itemKeysToRetrieve objectForKey:libraryID];
                    

                }
                
                //If we found a non-empty que, queue item retrival
                if(keyArray != NULL && [keyArray count]>0){
                    
                    if(libraryID == NULL){
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
                            NSString* timestamp = [_libraryTimestamps objectForKey:libraryID];
                            if(timestamp!=NULL){
                                //Update both the DB and the in-memory cache.
                                [[ZPDatabase instance] setUpdatedTimestampForLibrary:libraryID toValue:timestamp];
                                [[ZPZoteroLibrary dataObjectWithKey:libraryID] setCacheTimestamp:timestamp];
                                DDLogVerbose(@"Library %@ is now fully cached", libraryID);
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
                    DDLogVerbose(@"Started item retrieval operation. Operations in queue is %i. Number of items in queue for library %@ is %i",[_serverRequestQueue operationCount],libraryID,[keyArray count]);
                    
                }
                
            }

            // Last, check collection memberships
            @synchronized(_collectionsToCache){
                
                if([_collectionsToCache count]>0){
                    
                    NSOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_doContainerRetrieval:) object:[_collectionsToCache lastObject]];
                    
                    //Remove the items that we are retrieving
                    [_collectionsToCache removeLastObject];
                    
                    [_serverRequestQueue addOperation:retrieveOperation];
                    DDLogVerbose(@"Started collection retrieval operation. Operations in queue is %i. Number of collections in queue is %i",[_serverRequestQueue operationCount],[_collectionsToCache count]);
                    
                } 
                else break;
            }
        }
    }
}


- (void) _doItemRetrieval:(NSArray*) itemKeys fromLibrary:(NSNumber*)libraryID{
    
    DDLogVerbose(@"Retrieving items %@",[itemKeys componentsJoinedByString:@", "]);
    
    
    NSArray* items = [[ZPServerConnection instance] retrieveItemsFromLibrary:libraryID itemKeys:itemKeys];
        
    [self _cacheItemsAndAttachToParentsIfNeeded:items];

    //Perform checking the queue in another thread so that the current operation can exit
    DDLogVerbose(@"Rechecking queues");
    [self performSelectorInBackground:@selector(_checkQueues) withObject:NULL];
}


-(void) _cacheItemsAndAttachToParentsIfNeeded:(NSArray*) items{
    
    DDLogVerbose(@"Writing %i items to cache",[items count]);
           
    ZPZoteroItem* item;

    NSMutableArray* normalItems = [NSMutableArray array];
    NSMutableArray* standaloneNotesAndAttachments = [NSMutableArray array];
    NSMutableArray* attachments = [NSMutableArray array];
    NSMutableArray* notes = [NSMutableArray array];
    NSMutableArray* parentItemsForAttachments = [NSMutableArray array];
    NSMutableArray* parentItemsForNotes = [NSMutableArray array];
    
    for(item in items){
        if( [item needsToBeWrittenToCache]){

            //TODO: Refactor. This is very confusing. 
            
            
            /*
             
             The following if clause is used to prevent this bug from happening. A more robust fix is needed, but this is better done after refactoring the server connection code to use asynchronous requests and NSNotification.
             
             4 ZotPad beta 0x00091df7 -[ZPDatabase updateObjects:intoTable:] (ZPDatabase.m:256)
             5 ZotPad beta 0x00092635 -[ZPDatabase writeObjects:intoTable:checkTimestamp:] (ZPDatabase.m:347)
             6 ZotPad beta 0x00094849 -[ZPDatabase writeAttachments:] (ZPDatabase.m:727)
             7 ZotPad beta 0x00099099 -[ZPCacheController _cacheItemsAndAttachToParentsIfNeeded:] (ZPCacheController.m:433)
             8 ZotPad beta 0x00099aab -[ZPCacheController _updateItemDetailsFromServer:] (ZPCacheController.m:587)
             
             */
            if(item.serverTimestamp == NULL || item.serverTimestamp == [NSNull null]){
#ifdef DEBUG
                DDLogError(@"Item %@ has an empty server timestamp and will not be written to cache. The item was created from the following server response: \n\n%@",item.key,item.responseDataFromWhichThisItemWasCreated);
#endif
                continue;
            }
            
            item.cacheTimestamp = item.serverTimestamp;
            
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
            DDLogVerbose(@"Checking if we need to cache library %@",libraryID);
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
                 
                 DDLogVerbose(@"Adding items to queue up to last %i",index);
                 
                 // Queue all the items that were different
                 NSArray* itemKeysThatNeedToBeRetrieved = [serverKeys subarrayWithRange:NSMakeRange(0, [serverKeys count]-index-1)];
                 
                 */
                
                
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
    if(item == NULL){
        [NSException raise:@"Item cannot be null" format:@"Method refresh active item was called with an argument that was null."];
    }
    [self performSelectorInBackground:@selector(_updateItemDetailsFromServer:) withObject:item];
    
}

-(void) _updateItemDetailsFromServer:(ZPZoteroItem*)item{

    if(item == NULL){
        [NSException raise:@"Item cannot be null" format:@"Method _updateItemDetailsFromServer was called with an argument that was null."];
    }
    _activeItemKey = item.key;
    
    item = [[ZPServerConnection instance] retrieveSingleItemDetailsFromServer:item];
    if(item != NULL){
        NSMutableArray* items = [NSMutableArray arrayWithObject:item];
        [items addObjectsFromArray:item.attachments];
        [items addObjectsFromArray:item.notes];
        
        [self _cacheItemsAndAttachToParentsIfNeeded:items];
        
        //The method call above will only fire a notification if the item was actually updated. Fire it here again so that we will always get a notification and know that the item has been updated.
        [[ZPDataLayer instance] notifyItemsAvailable:[NSArray arrayWithObject:item]];
    }       
}

-(void) setActiveLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey{

    
    
    if(! [libraryID isEqual:_activelibraryID] && ! [[ZPPreferences instance] cacheAttachmentsAllLibraries] ){
        @synchronized(_filesToDownload){
            [_filesToDownload removeAllObjects];
        }
        //        DDLogVerbose(@"Clearing attachment download queue because library changed and preferences do not indicate that all libraries should be downloaded");
    }
    
    //Store the libraryID and collectionKEy
    _activelibraryID = libraryID;
    
    //Both keys might be null, so we need to compare equality directly as well
    if(! (collectionKey == _activeCollectionKey || [collectionKey isEqual:_activeCollectionKey]) && ! [[ZPPreferences instance] cacheAttachmentsActiveLibrary]){
        @synchronized(_filesToDownload){
            
            [_filesToDownload removeAllObjects];
        }
        //        DDLogVerbose(@"Clearing attachment download queue because collection changed and preferences do not indicate that all collections should be downloaded");
    }
    _activeCollectionKey = collectionKey;
    
    //Add attachments to queue

    //TODO: Refactor so that this block is not needed
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{

        NSArray* itemKeysToCheck = [[ZPDatabase instance] getItemKeysForLibrary:libraryID collectionKey:collectionKey searchString:NULL orderField:NULL sortDescending:FALSE];
        [self _checkIfAttachmentsExistWithParentKeysAndQueueForDownload:itemKeysToCheck];
    });
    
    //Check if the container needs a refresh
    if(collectionKey == NULL){
        [self performSelectorInBackground:@selector(_checkIfLibraryNeedsCacheRefreshAndQueue:) withObject:libraryID];   
    }
    else{
        [self performSelectorInBackground:@selector(_checkIfCollectionNeedsCacheRefreshAndQueue:) withObject:collectionKey];
    }
}
-(void) _checkIfAttachmentsExistWithParentKeysAndQueueForDownload:(NSArray*)parentKeys{

    for(NSString* key in parentKeys){
        ZPZoteroItem* item = (ZPZoteroItem*) [ZPZoteroItem dataObjectWithKey:key];

        //Troubleshooting
        
        //TODO: Remove this workaround
        NSArray* attachments = item.attachments;
        
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
            else if(_activeCollectionKey!= NULL && [parent.collections containsObject:[ZPZoteroCollection dataObjectWithKey:_activeCollectionKey] ]){
                doCache = true;
            }
        }
        else if([[ZPPreferences instance] cacheAttachmentsActiveItem]){
            doCache =( attachment.parentItemKey == _activeItemKey);
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
    if([_libraryTimestamps objectForKey:object.libraryID] == NULL){
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

    //TODO: This does not currently remove libraries from the UI if they are removed from the key

    if(! _isRefresingLibraries){
        _isRefresingLibraries = TRUE;
 
        DDLogVerbose(@"Loading library information from server");
        NSArray* libraries = [[ZPServerConnection instance] retrieveLibrariesFromServer];
        
        if(libraries!=NULL){
            
            NSEnumerator* e = [libraries objectEnumerator];
            
            ZPZoteroLibrary* library;
            
            while ( library = (ZPZoteroLibrary*) [e nextObject]) {
                
                [self performSelectorInBackground:@selector(updateCollectionsForLibraryFromServer:) withObject:library];
                
            }
            [[ZPDatabase instance] writeLibraries:libraries];
        }
        
        _isRefresingLibraries = FALSE;
    }
}

-(void) updateCollectionsForLibraryFromServer:(ZPZoteroLibrary*) library{

    
    BOOL shouldRefresh = FALSE;
    @synchronized(_librariesWhoseCollectionsAreBeingRefreshed){
        if(! [_librariesWhoseCollectionsAreBeingRefreshed containsObject:library.libraryID]){
            shouldRefresh = TRUE;
            [_librariesWhoseCollectionsAreBeingRefreshed addObject:library.libraryID];
        }
    }
    
    if(shouldRefresh){
        DDLogVerbose(@"Loading collections for library %@",library.title);

        NSArray* collections = [[ZPServerConnection instance] retrieveCollectionsForLibraryFromServer:library.libraryID];
        if(collections!=NULL){
            [[ZPDatabase instance] writeCollections:collections toLibrary:library];
            [[ZPDataLayer instance] notifyLibraryWithCollectionsAvailable:library];
        }
        @synchronized(_librariesWhoseCollectionsAreBeingRefreshed){
            [_librariesWhoseCollectionsAreBeingRefreshed removeObject:library.libraryID];
        }
    }
}

#pragma mark -
#pragma mark Notifier methods for metadata



-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library{
    if([[ZPPreferences instance] cacheMetadataAllLibraries]){
        [self _checkIfLibraryNeedsCacheRefreshAndQueue:library.libraryID];
        [self _checkQueues];
    }
}




#pragma mark -
#pragma mark Attachment cache


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
        [[ZPPreferences instance] setCurrentCacheSize:[NSString stringWithFormat:@"%i MB",temp]];
        
    }
    else{
        float temp = ((float)_sizeOfDocumentsFolder)/1048576;
        [[ZPPreferences instance] setCurrentCacheSize:[NSString stringWithFormat:@"%.1f GB",temp]];
    }
    //Also update the view if it has been defined
    if(_statusView !=NULL){
        NSInteger maxCacheSize = [[ZPPreferences instance] maxCacheSize];
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
        NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:[_documentsDirectory stringByAppendingPathComponent:_documentFilePath] traverseLink:YES];
        NSInteger thisSize = [_documentFileAttributes fileSize]/1024;
        _documentsFolderSize += thisSize;
        //DDLogVerbose(@"Cache size is %i after including %@ (%i)",(NSInteger) _documentsFolderSize,_documentFilePath,thisSize);
    }
    
    return _documentsFolderSize;
}

- (void) _updateCacheSizeAfterAddingAttachment:(ZPZoteroAttachment*)attachment{
    if(_sizeOfDocumentsFolder!=0){
        
        NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:attachment.fileSystemPath traverseLink:YES];
        _sizeOfDocumentsFolder += [_documentFileAttributes fileSize]/1024;
        DDLogInfo(@"Cache size is %i KB after adding %@ (%i KB)",(NSInteger)_sizeOfDocumentsFolder,attachment.fileSystemPath,[_documentFileAttributes fileSize]/1024);


//        DDLogVerbose(@"Cache size after adding %@ to cache is %i",attachment.fileSystemPath,_sizeOfDocumentsFolder);

        if(_sizeOfDocumentsFolder>=[[ZPPreferences instance] maxCacheSize]) [self _cleanUpCache];
        [self _updateCacheSizePreference];
    }
}

- (void) _cleanUpCache{
    
    DDLogWarn(@"Start cleaning cached files");
    
    NSArray* attachments = [[ZPDatabase instance] getCachedAttachmentsOrderedByRemovalPriority];

    //Delete orphaned files
    
    NSString* _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_documentsDirectory error:NULL];
    
    ZPZoteroAttachment* attachment;
    
    for (NSString* _documentFilePath in directoryContent) {
        NSString* path = [_documentsDirectory stringByAppendingPathComponent:_documentFilePath];

        if(! [_documentFilePath isEqualToString: @"zotpad.sqlite"] && ! [_documentFilePath isEqualToString:@"zotpad.sqlite-journal"] && ! [_documentFilePath hasPrefix:@"log-"]){
            
            // The strings from DB and file system have different encodings. Because of this, we cannot scan the array using built-in functions, but need to loop over it
            NSString* pathFromDB;
            BOOL found = FALSE;
         
            for(attachment in attachments){
                pathFromDB=attachment.fileSystemPath;
                if([pathFromDB compare:path] == NSOrderedSame){
                    found=TRUE;
                    break;
                }
            }
            
            // If the file was not found in DB, delete it
            
            if(! found){
                NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES];
                _sizeOfDocumentsFolder -= [_documentFileAttributes fileSize]/1024;
                DDLogWarn(@"Deleting orphaned file %@. Cache use is now at %i\%",path,_sizeOfDocumentsFolder*100/[[ZPPreferences instance] maxCacheSize]);
                [[NSFileManager defaultManager] removeItemAtPath:path error: NULL];
            }
        }
    }
    
    
    //Delete attachment files until the size of the cache is below the maximum size
    NSInteger maxCacheSize =[[ZPPreferences instance] maxCacheSize];
    if (_sizeOfDocumentsFolder>maxCacheSize){
        for(attachment in attachments){

            //Only delete originals
            [attachment purge_original:@"Automatic cache cleaning to reclaim space"];
            
            if (_sizeOfDocumentsFolder<=[[ZPPreferences instance] maxCacheSize]) break;
        }
    }
    DDLogWarn(@"Done cleaning cached files");

}

-(void) addAttachmentToUploadQueue:(ZPZoteroAttachment*) attachment withNewFile:(NSURL*)urlToFile{

    //Move the file to right place and increment cache size
    [attachment moveFileFromPathAsNewModifiedFile:[urlToFile path]];

    //TODO: Refactor cache size modifications to notifications
    NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:attachment.fileSystemPath_modified traverseLink:YES];
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
