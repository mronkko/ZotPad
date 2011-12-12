//
//  ZPDataLayer.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPDetailedItemListViewController.h"
#import "ZPItemRetrieveOperation.h"
#import "ZPZoteroItem.h"
#import "ZPItemObserver.h"

#import "../FMDB/src/FMDatabase.h"
#import "../FMDB/src/FMResultSet.h"

@interface ZPDataLayer : NSObject {
    
    // Is the library and collection tree synced with the server
    BOOL _collectionTreeCached;
    
    // Status for cached collection content
    // 0 or null = no cache
    // 1 = cache started
    // 2 = item IDs and item basic information cached
    // 3 = item details cached 
    // 4 = child items cached

    
    NSMutableDictionary* _collectionCacheStatus;


    // An operation que to fetch items in the background
    NSOperationQueue* _serverRequestQueue;

    // An operation que to write items in the cache in the background
    NSOperationQueue* _itemCacheWriteQueue;
    
    NSString* _currentlyActiveCollectionKey;
    NSInteger _currentlyActiveLibraryID;
    
    ZPItemRetrieveOperation* _mostRecentItemRetrieveOperation;

    BOOL _debugDataLayer;
    
    NSMutableSet* _itemObservers;
    
    FMDatabase* _database;
}

// This class is used as a singleton
+ (ZPDataLayer*) instance;

//Methods to get details of the current selection
//TODO: Should these belong to the UI delegates instead? 
-(NSString*) currentlyActiveCollectionKey;
-(NSInteger) currentlyActiveLibraryID;

// Methods for explicitly requesting updated data from server
-(void) updateLibrariesAndCollectionsFromServer;
-(void) updateItemDetailsFromServer:(ZPZoteroItem*)item;

// Methods for retrieving data from the data layer
- (NSArray*) libraries;
- (NSArray*) collections : (NSInteger)currentLibraryID currentCollection:(NSInteger)currentCollectionID;
- (NSArray*) getItemKeysForSelection:(ZPDetailedItemListViewController*)view;
- (ZPZoteroItem*) getItemByKey: (NSString*) key;

//Add more data to an existing item. By default the getItemByKey do not populate fields or creators to save database operations
- (void) addFieldsToItem: (ZPZoteroItem*) item;
- (void) addCreatorsToItem: (ZPZoteroItem*) item;

- (NSString*) collectionKeyFromCollectionID:(NSInteger) collectionID;

// Methods for writing data to database
-(void) cacheZoteroItems:(NSArray*)items;
-(void) addItemToDatabase:(ZPZoteroItem*)item;

//Adds and removes observers
-(void) registerItemObserver:(NSObject<ZPItemObserver>*)observer;
-(void) removeItemObserver:(NSObject<ZPItemObserver>*)observer;

//Notifies all observers that a new item is available
-(void) notifyItemBasicsAvailable:(ZPZoteroItem*)item;
-(void) notifyItemDetailsAvailable:(ZPZoteroItem*)item;
-(void) notifyItemAttachmentsAvailable:(ZPZoteroItem*)item;


@property (retain) ZPItemRetrieveOperation* mostRecentItemRetriveOperation;

@end
