//
//  ZPDataLayer.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPDetailViewController.h"
#import "ZPItemRetrieveOperation.h"
#import "ZPZoteroItem.h"
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
    
    FMDatabase* _database;
}

// This class is used as a singleton
+ (ZPDataLayer*) instance;

-(void) updateLibrariesAndCollectionsFromServer;

//This is a private method that does the actual work for retrieving libraries and collections
-(void) _updateLibrariesAndCollectionsFromServer;

- (NSArray*) libraries;
- (NSArray*) collections : (NSInteger)currentLibraryID currentCollection:(NSInteger)currentCollectionID;

- (NSArray*) getItemKeysForView:(ZPDetailViewController*)view;

//Retrieves the initial 15 items, called from getItemKeysForView and executed as operation
- (void) _retrieveAndSetInitialKeysForView:(ZPDetailViewController*)view;

- (ZPZoteroItem*) getItemByKey: (NSString*) key;
- (NSDictionary*) getFieldsForItem: (NSInteger) itemID;
- (NSArray*) getCreatorsForItem: (NSInteger) itemID;
- (NSArray*) getAttachmentFilePathsForItem: (NSInteger) itemID;
- (NSString*) collectionKeyFromCollectionID:(NSInteger) collectionID;

-(void) cacheZoteroItems:(NSArray*)items;
-(void) addItemToDatabase:(ZPZoteroItem*)item;

-(NSString*) currentlyActiveCollectionKey;
-(NSInteger) currentlyActiveLibraryID;


@end
