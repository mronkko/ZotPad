//
//  ZPDataLayer.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import "ZPDetailViewController.h"
#import "ZPItemRetrieveOperation.h"
#import "ZPZoteroItem.h"

@interface ZPDataLayer : NSObject {
	sqlite3 *database;
    
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
    NSOperationQueue* _itemRetrieveQueue;

    // An operation que to write items in the cache in the background
    NSOperationQueue* _itemCacheWriteQueue;
    
    NSString* _currentlyActiveCollectionKey;
    
    ZPItemRetrieveOperation* _mostRecentItemRetrieveOperation;

    BOOL _debugDatabase;
}

// This class is used as a singleton
+ (ZPDataLayer*) instance;

- (NSArray*) libraries;
- (NSArray*) collections : (NSInteger)currentLibraryID currentCollection:(NSInteger)currentCollectionID;

- (NSArray*) getItemKeysForView:(ZPDetailViewController*)view;
- (ZPZoteroItem*) getItemByKey: (NSString*) key;
- (NSDictionary*) getFieldsForItem: (NSInteger) itemID;
- (NSArray*) getCreatorsForItem: (NSInteger) itemID;
- (NSArray*) getAttachmentFilePathsForItem: (NSInteger) itemID;
- (NSString*) collectionKeyFromCollectionID:(NSInteger) collectionID;

-(void) cacheZoteroItems:(NSArray*)items;
-(void) addItemToDatabase:(ZPZoteroItem*)item;

-(NSString*) currentlyActiveCollectionKey;


// Helper functions to prepare and execute statements. All SQL queries should be done through these

-(sqlite3_stmt*) prepareStatement:(NSString*) sqlString;
-(void) executeStatement:(NSString*) sqlString;

@end
