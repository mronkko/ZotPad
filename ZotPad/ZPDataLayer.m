
//
//  ZPDataLayer.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

//TODO: Consider splitting this class into (maybe) three parts 1) General data layer, 2) Database operations, 3) Cache

#import "ZPDataLayer.h"

//Data objects
#import "ZPZoteroLibrary.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroItem.h"

//Operations
#import "ZPItemCacheWriteOperation.h"
#import "ZPItemRetrieveOperation.h"

//Server connection
#import "ZPServerConnection.h"
#import "ZPServerResponseXMLParser.h"

//User interface
#import "ZPLibraryAndCollectionListViewController.h"

//DB and DB library
#import "ZPDatabase.h"




//Private methods 

@interface ZPDataLayer ();
//This is a private method that does the actual work for retrieving libraries and collections
-(void) _updateLibrariesAndCollectionsFromServer;

//Retrieves the initial 15 items, called from getItemKeysForView and executed as operation
- (void) _retrieveAndSetInitialKeysForView:(ZPDetailedItemListViewController*)view;

//Gets one item details and writes these to the database
-(void) _updateItemDetailsFromServer:(ZPZoteroItem*) item;
    
//Extract data from item and write to database

-(void) _writeItemCreatorsToDatabase:(ZPZoteroItem*)item;
-(void) _writeItemFieldsToDatabase:(ZPZoteroItem*)item;
        
//- (NSArray*) getAttachmentFilePathsForItem: (NSInteger) itemID;


@end




@implementation ZPDataLayer

@synthesize mostRecentItemRetriveOperation = _mostRecentItemRetrieveOperation;



static ZPDataLayer* _instance = nil;


-(id)init
{
    self = [super init];
    
    _debugDataLayer = TRUE;
        
    _itemObservers = [[NSMutableSet alloc] initWithCapacity:2];
    
    //Initialize OperationQueues for retrieving data from server and writing it to cache
    _serverRequestQueue = [[NSOperationQueue alloc] init];
    _itemCacheWriteQueue = [[NSOperationQueue alloc] init];
    
    _collectionTreeCached = FALSE;
    _collectionCacheStatus = [[NSMutableDictionary alloc] init];
    
  
    
	return self;
}

/*
    Singleton accessor
 */

+(ZPDataLayer*) instance {
    if(_instance == NULL){
        _instance = [[ZPDataLayer alloc] init];
    }
    return _instance;
}

/*
 
 Returns the key to the most recently used collection. Used in prioritizing item retrieve operations.
 
 */

-(NSString*) currentlyActiveCollectionKey{
    return _currentlyActiveCollectionKey;

}
-(NSInteger) currentlyActiveLibraryID{
    return _currentlyActiveLibraryID;
    
}

/*
 Updates the local cache for libraries and collections and retrieves this data from the server
 */

-(void) updateLibrariesAndCollectionsFromServer{
    NSInvocationOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                         selector:@selector(_updateLibrariesAndCollectionsFromServer) object:NULL];
    [_serverRequestQueue addOperation:retrieveOperation];
    NSLog(@"Opertions in queue %i",[_serverRequestQueue operationCount]);

}

-(void) _updateLibrariesAndCollectionsFromServer{
    
    
    NSLog(@"Loading group library information from server");
    NSArray* libraries = [[ZPServerConnection instance] retrieveLibrariesFromServer];
    if(libraries==NULL) return;
    
    [[ZPDatabase instance] addOrUpdateLibraries:libraries];
    
    NSEnumerator* e = [libraries objectEnumerator];
    
    ZPZoteroLibrary* library;
    
    while ( library = (ZPZoteroLibrary*) [e nextObject]) {
             
        NSArray* collections = [[ZPServerConnection instance] retrieveCollectionsForLibraryFromServer:library.libraryID];
        if(collections==NULL) return;
        
        [[ZPDatabase instance] addOrUpdateCollections:collections forLibrary:library.libraryID];

        [[ZPLibraryAndCollectionListViewController instance] notifyDataAvailable];
        
    }
    
    //Collections for My Library
    
    NSArray* collections = [[ZPServerConnection instance] retrieveCollectionsForLibraryFromServer:1];
    if(collections==NULL) return;
    [[ZPDatabase instance] addOrUpdateCollections:collections forLibrary:1];
    
    
    
    [[ZPLibraryAndCollectionListViewController instance] notifyDataAvailable];
}

/*
 
 Returns an array containing all libraries  
 
 */

- (NSArray*) libraries {
	
    return [[ZPDatabase instance] libraries];
}


/*
 
 Returns an array containing all libraries with their collections 
 
 */

- (NSArray*) collections : (NSInteger)currentLibraryID currentCollection:(NSInteger)currentCollectionID {
	
    return [[ZPDatabase instance] collections:currentLibraryID currentCollection:currentCollectionID];

}


/*
 
 Creates an array that will hold the item IDs of the current view. Initially contains only 15 first
    IDs with the rest of the item ids set to 0 and populated later in the bacground.

 */


- (NSArray*) getItemKeysForSelection:(ZPDetailedItemListViewController*)view{

    //If we have an ongoing item retrieval in teh background, tell it that it can stop
    
    [_mostRecentItemRetrieveOperation markAsNotWithActiveView];
    
    
    NSString* collectionKey = NULL;
    if(view.collectionID!=0){
        collectionKey = [self collectionKeyFromCollectionID:view.collectionID];
    }

    _currentlyActiveCollectionKey = collectionKey;
    _currentlyActiveLibraryID = view.libraryID;
     
    // Start by deciding if we need to connect to the server or can use cache. We can rely on cache
    // if this collection is completely cached already. Because there is no way to get information about
    // modified collection memberships from Zotero read API, without  
    
    NSNumber* cacheStatus = [_collectionCacheStatus objectForKey:[NSNumber numberWithInt:view.collectionID]];
    
    if( cacheStatus == NULL || [cacheStatus intValue] != 2 ){
        NSInvocationOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                                        selector:@selector(_retrieveAndSetInitialKeysForView:) object:view];
        [retrieveOperation setQueuePriority:NSOperationQueuePriorityVeryHigh];
        [_serverRequestQueue addOperation:retrieveOperation];
        NSLog(@"Opertions in queue %i",[_serverRequestQueue operationCount]);
        return NULL;
    }
    else{
        //TODO: Get the items from cache
        return NULL;
    }
}

- (void) _retrieveAndSetInitialKeysForView:(ZPDetailedItemListViewController*)view{

    NSInteger collectionID=view.collectionID;
    NSInteger libraryID =  view.libraryID;
    NSString* searchString = [view.searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString* OrderField = view.OrderField;
    BOOL sortDescending = view.sortDescending;

    NSString* collectionKey = NULL;

    if(collectionID!=0){
        collectionKey = [self collectionKeyFromCollectionID:view.collectionID];
    }
    
    //Retrieve initial 15 items
    
    ZPServerResponseXMLParser* parserResults = [[ZPServerConnection instance] retrieveItemsFromLibrary:libraryID collection:collectionKey searchString:searchString orderField:OrderField sortDescending:sortDescending limit:15 start:0];
    
    if(parserResults == NULL){
        [view setItemKeysShown: [NSArray array]];
        [view notifyDataAvailable];
    }
    else{
        //Construct a return array
        NSMutableArray* returnArray = [NSMutableArray arrayWithCapacity:[parserResults totalResults]];
        
        //Fill in what we got from the parser and pad with NULL
        
        for (int i = 0; i < [parserResults totalResults]; i++) {
            if(i<[[parserResults parsedElements] count]){
                ZPZoteroItem* item = (ZPZoteroItem*)[[parserResults parsedElements] objectAtIndex:i];
                [returnArray addObject:[item key]];
            }
            else{
                [returnArray addObject:[NSNull null]];
            }
        }
        
        //Que an operation to cache the results of the server response
        //TODO: Consider if these initial items should be given higher priority. It is possible that there are other items already in the queue.

        NSArray* items = [parserResults parsedElements];
                  
        [self cacheZoteroItems:items];
        
        //If the current collection has already been changed, do not queue any more retrievals
        if(!(_currentlyActiveLibraryID==libraryID &&
             ((collectionKey == NULL && _currentlyActiveCollectionKey == NULL) ||  
              [ collectionKey isEqualToString:_currentlyActiveCollectionKey] ))) return;
        
        
        //Retrieve the rest of the items into the array
        ZPItemRetrieveOperation* retrieveOperation = [[ZPItemRetrieveOperation alloc] initWithArray: returnArray library:libraryID collection:collectionKey searchString:searchString OrderField:OrderField sortDescending:sortDescending queue:_serverRequestQueue];
        
        
        
        //If this is the first time that we are using this collection, mark this operation as a cache operation if it does not have a search string or create a new operations without a search string
        
        NSNumber* cacheStatus = [_collectionCacheStatus objectForKey:[NSNumber numberWithInt:collectionID]];
        
        if([cacheStatus intValue] != 1){
            if (searchString== NULL || [searchString isEqualToString:@""] ){
                [retrieveOperation markAsInitialRequestForCollection];
                [_serverRequestQueue addOperation:retrieveOperation];
            }
            else{
                [_serverRequestQueue addOperation:retrieveOperation];
                
                //Start a new backround operation to retrieve all items in the colletion (the main request was filtered with sort)
                ZPItemRetrieveOperation* retrieveOperationForCache = [[ZPItemRetrieveOperation alloc] initWithArray: [NSArray array] library:libraryID collection:collectionKey searchString:NULL OrderField:NULL sortDescending:NO queue:_serverRequestQueue];
                [retrieveOperationForCache markAsInitialRequestForCollection];
                [_serverRequestQueue addOperation:retrieveOperationForCache];
            }
            // Mark that we have started retrieving things from the server 
            [_collectionCacheStatus setValue:[NSNumber numberWithInt:1] forKey:[NSString stringWithFormat:@"%i",collectionID]];
        }
        
        [view setItemKeysShown: returnArray];
        [view notifyDataAvailable];
        
    }
}

-(void) cacheZoteroItems:(NSArray*)items {
    ZPItemCacheWriteOperation* cacheWriteOperation = [[ZPItemCacheWriteOperation alloc] initWithZoteroItemArray:items];
    [_itemCacheWriteQueue addOperation:cacheWriteOperation];
}


- (ZPZoteroItem*) getItemByKey: (NSString*) key{

    return [[ZPDatabase instance] getItemByKey:key];
}

/*
 
 Retrieves item details from the server and writes them in the database in the background
 
 */

-(void) updateItemDetailsFromServer:(ZPZoteroItem*)item{
    
    NSInvocationOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                                    selector:@selector(_updateItemDetailsFromServer:) object:item];

    [retrieveOperation setQueuePriority:NSOperationQueuePriorityVeryHigh];
    
    [_serverRequestQueue addOperation:retrieveOperation];
    NSLog(@"Opertions in queue %i",[_serverRequestQueue operationCount]);
}

-(void) _updateItemDetailsFromServer:(ZPZoteroItem*)item{
    item = [[ZPServerConnection instance] retrieveSingleItemDetailsFromServer:item];
    [self _writeItemFieldsToDatabase:item];
    [self _writeItemCreatorsToDatabase:item];
    
    [self notifyItemDetailsAvailable:item];

}

//Notifies all observers that a new item is available
-(void) notifyItemBasicsAvailable:(ZPZoteroItem*)item{

    NSEnumerator* e = [_itemObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([(NSObject <ZPItemObserver>*) id respondsToSelector:@selector(notifyItemBasicsAvailable:)]){
            [(NSObject <ZPItemObserver>*) id notifyItemBasicsAvailable:item];
        }
    }
}

//Notifies all observers that a new item is available
-(void) notifyItemDetailsAvailable:(ZPZoteroItem*)item{
    
    NSEnumerator* e = [_itemObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([(NSObject <ZPItemObserver>*) id respondsToSelector:@selector(notifyItemDetailsAvailable:)]){
            [(NSObject <ZPItemObserver>*) id notifyItemDetailsAvailable:item];
        }
    }
}

-(void) notifyItemAttachmentsAvailable:(ZPZoteroItem*)item{
    
    NSEnumerator* e = [_itemObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([(NSObject <ZPItemObserver>*) id respondsToSelector:@selector(notifyItemAttachmentsAvailable:)]){
            [(NSObject <ZPItemObserver>*) id notifyItemAttachmentsAvailable:item];
        }
    }
}

-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library{
    NSEnumerator* e = [_libraryObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        [(NSObject <ZPLibraryObserver>*) id notifyLibraryWithCollectionsAvailable:library];
    }
    
}


//Adds and removes observers
-(void) registerItemObserver:(NSObject<ZPItemObserver>*)observer{
    [_itemObservers addObject:observer];
    
}
-(void) removeItemObserver:(NSObject<ZPItemObserver>*)observer{
    [_itemObservers removeObject:observer];
}

-(void) registerLibraryObserver:(NSObject<ZPLibraryObserver>*)observer{
    [_libraryObservers addObject:observer];
    
}
-(void) removeLibraryObserver:(NSObject<ZPLibraryObserver>*)observer{
    [_libraryObservers removeObject:observer];
}

@end
