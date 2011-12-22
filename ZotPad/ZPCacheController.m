//
//  ZPCache.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPCacheController.h"
#import "ZPPreferences.h"
#import "ZPDataLayer.h"
#import "ZPDatabase.h"
#import "ZPServerResponseXMLParser.h"
#import "ZPServerConnection.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroItemContainer.h"


#define NUMBER_OF_ITEMS_TO_RETRIEVE 50
#define NUMBER_OF_ITEMS_NOT_YET_KNOWN -1

//This is a helper class for cache controller

@interface ZPCacheControllerData : NSObject <NSCopying> {
    NSMutableArray* itemKeys;
    NSInteger offset;
    NSInteger totalItems;
    NSNumber* libraryID;
    NSString* collectionKey;
    NSString* updatedTimeStamp;
    ZPZoteroItemContainer* targetZoteroItemContainer;
}
@property (retain) NSString* collectionKey;
@property (retain) NSString* updatedTimeStamp;
@property (retain) NSNumber* libraryID;
@property (retain) NSMutableArray* itemKeys;
@property NSInteger offset;
@property NSInteger totalItems;
@property (retain) ZPZoteroItemContainer* targetZoteroItemContainer;

- (id)copyWithZone:(NSZone*)zone;

@end

@implementation ZPCacheControllerData 

@synthesize updatedTimeStamp;
@synthesize collectionKey;
@synthesize libraryID;
@synthesize itemKeys;
@synthesize offset;
@synthesize totalItems;
@synthesize targetZoteroItemContainer;

- (id) init{
    self= [super init];
    totalItems =  NUMBER_OF_ITEMS_NOT_YET_KNOWN;
    return self;
}

- (id)copyWithZone:(NSZone *)zone{
    ZPCacheControllerData* copy = [[ZPCacheControllerData alloc] init];
    copy.itemKeys = itemKeys;
    copy.offset = offset;
    copy.totalItems = totalItems;
    copy.libraryID = libraryID;
    copy.collectionKey = collectionKey;
    copy.updatedTimeStamp = updatedTimeStamp;
    copy.targetZoteroItemContainer = targetZoteroItemContainer;
    
    return copy;
}

@end


@interface ZPCacheController (){
    NSMutableArray* _currentlyActiveRetrievals;
}

-(void) _checkQueues;
-(void) _checkMetadataQueue;
-(void) _checkDownloadQueue;
-(BOOL) _checkIfNeedsMoreItemsAndQueue:(NSObject*) key;
-(void) _doItemRetrieval:(ZPCacheControllerData*) data;
-(void) _checkIfCacheRefreshNeededAndQueue:(ZPCacheControllerData*)data;

-(ZPCacheControllerData*) _cacheControllerDataObjectForZoteroItemContainer:(ZPZoteroItemContainer*)object;
-(void) _queueCacheRefreshWithCacheControllerData:(ZPCacheControllerData*)object;

-(void) _cleanUpCompletedWithKey:(NSObject*)key;
-(void) _updateLibrariesAndCollectionsFromServer;

// Refreshes collections and libraries from server
- (ZPZoteroCollection*) _getRefreshedCollection:(NSString*)collectionKey fromLibrary:(NSNumber*)libraryID;
- (ZPZoteroLibrary*) _getRefreshedLibrary:(NSNumber*)libraryID;

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
    [_fileDownloadQueue  setMaxConcurrentOperationCount:1];
    
    //These two arrays contain a list of IDs/Keys that will be cached. They have been already checked so that we know that recaching is needed
    
    _libraryIDsToCache = [[NSMutableArray alloc] init];
    _collectionKeysToCache = [[NSMutableArray alloc] init];
    
    _itemKeysForAttachmentsToCache = [[NSMutableArray alloc] init];
    
    _cacheDataObjects = [[NSMutableDictionary alloc] init];

    
    _currentlyActiveRetrievals = [NSMutableArray arrayWithCapacity:10];
    
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

    //Set up initial retrievals
    [self updateLibrariesAndCollectionsFromServer];
    
   

}

/*
 
 Checks if there are things to cache and starts processing these if there is something to retrieve.
 
*/

-(void) _checkQueues{
    [self _checkDownloadQueue];
    [self _checkMetadataQueue];
}

-(void) _checkDownloadQueue{
    //TODO Implement attachment downloads
}

-(void) _checkMetadataQueue{
    
    @synchronized(self){
        if([_serverRequestQueue operationCount] <= [_serverRequestQueue maxConcurrentOperationCount]){
            
            BOOL retrieving = FALSE;
            
            //If we have root of a library visible, prioritize it 
            if(_currentlyActiveLibraryID !=NULL && _currentlyActiveCollectionKey == NULL && [_libraryIDsToCache containsObject:_currentlyActiveLibraryID]){
                retrieving =  ([self _checkIfNeedsMoreItemsAndQueue:_currentlyActiveLibraryID]);             
            }
            
            //Otherwise, prioritize the visible collection 
            if(! retrieving && _currentlyActiveCollectionKey !=NULL && [_collectionKeysToCache containsObject:_currentlyActiveCollectionKey]){
                retrieving =  ([self _checkIfNeedsMoreItemsAndQueue:_currentlyActiveCollectionKey]);
            }
            
            //If the active views do not have items to retrieve, retrieve items for the first library in the queue
            
            
            if(! retrieving) for(NSObject* key in _libraryIDsToCache){
                if ([self _checkIfNeedsMoreItemsAndQueue:key]){
                    retrieving = TRUE;
                    break;
                }
            }
            
            if(! retrieving) for(NSObject* key in _collectionKeysToCache){
                retrieving = TRUE;
                break;
            }
            
            //Check if we can schedule a new operation immediately.
            if(retrieving) [self _checkQueues];
            
        }
    }
}

/*
 Cheks if more items are needed for a container, and if so, queues a new retrieval and updates offset
 */

-(BOOL) _checkIfNeedsMoreItemsAndQueue:(NSObject*) key{


    //Only one retrieval at a time
    if([_currentlyActiveRetrievals containsObject:key]) return false;

    ZPCacheControllerData* data = [_cacheDataObjects objectForKey:key];
    

    if((data.offset < data.totalItems) || (data.totalItems == NUMBER_OF_ITEMS_NOT_YET_KNOWN)){
        
        
        [_currentlyActiveRetrievals addObject:key];
        NSOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self                                                                                           selector:@selector(_doItemRetrieval:) object:[data copyWithZone:NULL]];

        [_serverRequestQueue addOperation:retrieveOperation];
        
        data.offset=data.offset+NUMBER_OF_ITEMS_TO_RETRIEVE;
        
        if((data.offset >= data.totalItems) && (data.totalItems != NUMBER_OF_ITEMS_NOT_YET_KNOWN)) [self _cleanUpCompletedWithKey:key];

        return true;
    }
    else{
        //The script should basically never get here. This clean up is just in case. There is no ocasion that it should be called
        [self _cleanUpCompletedWithKey:key];
        return false;
    }
}

-(void)_cleanUpCompletedWithKey:(NSObject*)key{
    ZPCacheControllerData* data = [_cacheDataObjects objectForKey:key];
    [_cacheDataObjects removeObjectForKey:key];
    if(data.collectionKey != NULL) [_collectionKeysToCache removeObject:data.collectionKey];
    else [_libraryIDsToCache removeObject:data.libraryID];
}

- (void) _doItemRetrieval:(ZPCacheControllerData*)data{
    
    //TODO: For a future version, do not request detailed item data if we already have it. 
    // (If a library is completely cached, it makes no sense to retrive the item metadata again for every collection.)
    
    ZPServerResponseXMLParser* parserResults = [[ZPServerConnection instance] retrieveItemsFromLibrary:data.libraryID collection:data.collectionKey
                                                                                          searchString:NULL orderField:NULL
                                                                                        sortDescending:FALSE limit:NUMBER_OF_ITEMS_TO_RETRIEVE
                                                                                                 start:data.offset];

    //Mark that this is no longer retrieving data
    if(data.collectionKey == NULL)
        [_currentlyActiveRetrievals removeObject:data.libraryID];
    else
        [_currentlyActiveRetrievals removeObject:data.collectionKey];
        
    //Only process on response at a time
    
   
    @synchronized(self){
        
        //First possibility is that we do not know when the server data was last updated (such as when doing a first retrieval for a library)
        if(data.updatedTimeStamp == NULL){

            if(data.collectionKey!=NULL){
                [NSException raise:@"Collection key is null" format:@"TODO: Write a description here"];
            }
            
            // The second thing to check is if we are receiving something that is already in the cache and up to date
            // This is possible with libraries, because there is no way of checking if a library has been updated but to
            // start retrieving it. This only applies to libraries, not collections.
            
            if(data.collectionKey==NULL && [parserResults.updateTimeStamp isEqualToString:data.targetZoteroItemContainer.serverTimeStamp]){
                [self _cleanUpCompletedWithKey:data.libraryID];
                [self _checkQueues];
                return;
            }
            else{
                //Check if this retrieval is still in queue, reset it
                ZPCacheControllerData* dataInQueue = [_cacheDataObjects objectForKey:data.libraryID];
                data.updatedTimeStamp = parserResults.updateTimeStamp;
                dataInQueue.updatedTimeStamp = parserResults.updateTimeStamp;
            }

        }

        /*
         
        //If the number of total rows in the set has changed, we need to reschedule this retrieval
        //This is extremely rare, but possible
         
        if(![[parserResults updateTimeStamp] != data.totalItems]){
            
            //First possibility is that we do not know when the server data was last updated (such as when doing a first retrieval for a library)
            
            
            
            //The second possibility is that the data on the server has changed
            
            NSObject* key;
            if(data.collectionKey==NULL){
                key= data.libraryID;
            }
            else{
                key=data.collectionKey;
            }
           
            //Check if this retrieval is still in queue, reset it
            ZPCacheControllerData* dataInQueue = [_cacheDataObjects objectForKey:key];
            if(dataInQueue != NULL && [dataInQueue.updatedTimeStamp isEqualToString:data.updatedTimeStamp]){
                //Reset this object
                [dataInQueue.itemKeys removeAllObjects];
                dataInQueue.offset = 0;
                dataInQueue.totalItems = NUMBER_OF_ITEMS_NOT_YET_KNOWN;
                dataInQueue.updatedTimeStamp = data.updatedTimeStamp;
            }
            
        }
        
        
        else{
         */
        
            if(data.totalItems == NUMBER_OF_ITEMS_NOT_YET_KNOWN){
                data.totalItems = parserResults.totalResults;
            
                //Pad with NSNull to get an array with appropriate length
                while([data.itemKeys count]< parserResults.totalResults){
                    [data.itemKeys addObject:[NSNull null]];
                }
            }
            for (ZPZoteroItem* item in [parserResults parsedElements]) {
                
                
                [[ZPDatabase instance] addItemToDatabase:item];
                if(data.collectionKey!=NULL){
                    [[ZPDatabase instance] addItem:item toCollection:data.collectionKey];
                }
                
                [data.itemKeys replaceObjectAtIndex:data.offset withObject:item.key];
                data.offset++;
            }
            

            //Notify the UI that the item list has changed
            [[ZPDataLayer instance] notifyItemKeyArrayUpdated:data.itemKeys];
            
            //Is the container now completely cached? 
            if([data.itemKeys lastObject] != [NSNull null]){
                if(data.collectionKey==NULL){
                    [[ZPDatabase instance] deleteItemsNotInArray:data.itemKeys fromLibrary:data.libraryID]; 
                    [[ZPDatabase instance] setUpdatedTimeStampForLibrary:data.libraryID toValue:data.updatedTimeStamp];
                }
                else{
                    [[ZPDatabase instance] removeItemsNotInArray:data.itemKeys fromCollection:data.collectionKey inLibrary:data.libraryID]; 
                    [[ZPDatabase instance] setUpdatedTimeStampForCollection:data.collectionKey toValue:data.updatedTimeStamp];
                }
                
            }
        //}
    }
    
    [self _checkQueues];
}

/*
 This does the actual queueing of a cache retrieval
 */
-(void) _queueCacheRefreshWithCacheControllerData:(ZPCacheControllerData*)data{
    
    data.offset=0;
    
    while([data.itemKeys count]< data.totalItems){
        [data.itemKeys addObject:[NSNull null]];
    }

    if(data.collectionKey == NULL){
        [_libraryIDsToCache insertObject:data.libraryID atIndex:0];
        [_cacheDataObjects setObject:data forKey:data.libraryID];
    }
    else{
        [_collectionKeysToCache insertObject:data.collectionKey atIndex:0];
        [_cacheDataObjects setObject:data forKey:data.collectionKey];
    }
    
    [self _checkQueues];

}

-(void) _checkIfCacheRefreshNeededAndQueue:(ZPCacheControllerData*) data{
    
     ZPZoteroItemContainer* container;

    if(data.collectionKey == NULL){
        container = [self _getRefreshedLibrary:data.libraryID];
    }
    else{
        container = [self _getRefreshedCollection:data.collectionKey fromLibrary:data.libraryID];
    }

    
    if(! [container.serverTimeStamp isEqualToString:container.lastCompletedCacheTimestamp]){
        
        data.updatedTimeStamp = [container serverTimeStamp];
        data.totalItems = container.numItems;
        data.targetZoteroItemContainer = container;
        [self _queueCacheRefreshWithCacheControllerData:data];
    }
}

/*
 
 This is called
 
 */

-(ZPCacheControllerData*) _cacheControllerDataObjectForZoteroItemContainer:(ZPZoteroItemContainer*)object{
    
    ZPCacheControllerData* data = [[ZPCacheControllerData alloc] init];
    data.libraryID = [object libraryID];
    data.collectionKey = [object collectionKey];
    data.totalItems = object.numItems;
    data.itemKeys = [NSMutableArray array];
    data.updatedTimeStamp = [object serverTimeStamp];
    data.targetZoteroItemContainer = object;
    
    return data;
}
    
    
-(void) updateLibrariesAndCollectionsFromServer{
    NSInvocationOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                                    selector:@selector(_updateLibrariesAndCollectionsFromServer) object:NULL];
    [_serverRequestQueue addOperation:retrieveOperation];
    NSLog(@"Opertions in queue %i",[_serverRequestQueue operationCount]);
}

/*
 Updates the local cache for libraries and collections and retrieves this data from the server
 */


-(void) _updateLibrariesAndCollectionsFromServer{
    
    
    NSLog(@"Loading group library information from server");
    NSArray* libraries = [[ZPServerConnection instance] retrieveLibrariesFromServer];
    if(libraries==NULL) return;
    
    ZPZoteroLibrary* myLibrary = [ZPZoteroLibrary ZPZoteroLibraryWithID:[NSNumber numberWithInt:1]];

    libraries=[libraries arrayByAddingObject:myLibrary];
    
    [[ZPDatabase instance] addOrUpdateLibraries:libraries];
    
    NSEnumerator* e = [libraries objectEnumerator];
    
    ZPZoteroLibrary* library;
    
    while ( library = (ZPZoteroLibrary*) [e nextObject]) {
        
        NSArray* collections = [[ZPServerConnection instance] retrieveCollectionsForLibraryFromServer:library.libraryID];
        if(collections==NULL) return;
        
        [[ZPDatabase instance] addOrUpdateCollections:collections forLibrary:library.libraryID];
        
        [[ZPDataLayer instance] notifyLibraryWithCollectionsAvailable:library];
        
    }
    
}

- (ZPZoteroCollection*) _getRefreshedCollection:(NSString*)collectionKey fromLibrary:(NSNumber*)libraryID{
    return [[ZPServerConnection instance] retrieveCollection:collectionKey fromLibrary:libraryID];
}

- (ZPZoteroLibrary*) _getRefreshedLibrary:(NSNumber*)libraryID{
    return [[ZPServerConnection instance] retrieveLibrary:libraryID];

}

-(void) setCurrentCollection:(NSString*) collectionKey{
    _currentlyActiveCollectionKey = collectionKey;
}

-(void) setCurrentLibrary:(NSNumber*) libraryID{
    _currentlyActiveLibraryID = libraryID;
}

-(void) setCurrentItem:(NSString*) itemKey{
    //TODO: Implement. This should affect the attachment downloading priority
}



/*
 
 These two are the only methods that can initialize new cache bulding. The first is called when new library and
 collection information becomes available. In this case we alrady know if they need to be cached
 and also how many items they contain.
 
 
 When notifyLibraryWithCollectionsAvailable we already know the number of items that are included in a 
 group or library.
 
 */

-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library{
    
    if([[ZPPreferences instance] cacheAllLibraries]){
        if(! ([library.serverTimeStamp isEqualToString: library.lastCompletedCacheTimestamp ] || 
              [_libraryIDsToCache containsObject:[library libraryID]])){
            
            //Retrieve the number of top level items
            library = [[ZPServerConnection instance] retrieveLibrary:library.libraryID];
            
            [self _queueCacheRefreshWithCacheControllerData:[self _cacheControllerDataObjectForZoteroItemContainer:library]];
            
            //Retrieve all collections for this library and add them to cache
            for(ZPZoteroCollection* collection in [[ZPDatabase instance] allCollectionsForLibrary:library.libraryID]){
                
                if (! ([collection.serverTimeStamp isEqualToString:collection.lastCompletedCacheTimestamp] || 
                       [_collectionKeysToCache containsObject:[collection collectionKey]])){
                    [self _queueCacheRefreshWithCacheControllerData:[self _cacheControllerDataObjectForZoteroItemContainer:collection]];
                }
            }
        }
    }
}


/*
 
 
 */

-(NSArray*) cachedItemKeysForCollection:(NSString*)collectionKey libraryID:(NSNumber*)libraryID {
 
    NSObject* key;
    if(collectionKey==NULL){
        key= libraryID;
    }
    else{
        key= collectionKey;
    }
    
    ZPCacheControllerData* data =[_cacheDataObjects objectForKey:key];
    
    if(data == NULL){
        NSMutableArray* ret = [NSMutableArray array];
        data=[[ZPCacheControllerData alloc] init];
        [_cacheDataObjects setObject:data forKey:key];
        data.itemKeys = ret;
        data.libraryID = libraryID;
        data.collectionKey = collectionKey;

        [ _serverRequestQueue addOperation: [[NSInvocationOperation alloc] initWithTarget:self
                                              selector:@selector(_checkIfCacheRefreshNeededAndQueue:) object:data]];
        return ret;
    }
    else return [data itemKeys];
    
}



@end
