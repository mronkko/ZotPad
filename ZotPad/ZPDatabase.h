//
//  ZPDatabase.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroItem.h"
#import "../FMDB/src/FMDatabase.h"
#import "../FMDB/src/FMResultSet.h"

@interface ZPDatabase : NSObject{
     
    FMDatabase* _database;
    BOOL _debugDatabase;
}

// This class is used as a singleton
+ (ZPDatabase*) instance;


-(void) addOrUpdateLibraries:(NSArray*)libraries;
-(void) addOrUpdateCollections:(NSArray*)collections forLibrary:(NSNumber*)libraryID;


// Methods for retrieving data from the data layer
- (NSArray*) libraries;
- (NSArray*) collectionsForLibrary : (NSNumber*)currentLibraryID withParentCollection:(NSString*)currentCollectionKey;
- (NSArray*) allCollectionsForLibrary: (NSNumber*)libraryID;
- (ZPZoteroItem*) getItemByKey: (NSString*) key;
- (NSArray*) getItemKeysForLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey
                      searchString:(NSString*)searchString orderField:(NSString*)OrderField sortDescending:(BOOL)sortDescending;

//Add more data to an existing item. By default the getItemByKey do not populate fields or creators to save database operations
- (void) getFieldsForItemKey: (NSString*) key;
- (void) getCreatorsForItemKey: (NSString*) key;


// Methods for writing data to database
-(void) addItemToDatabase:(ZPZoteroItem*)item;

// Records a new collection membership
-(void) addItem:(ZPZoteroItem*)item toCollection:(NSString*)collectionKey;

//Extract data from item and write to database

-(void) writeItemCreatorsToDatabase:(ZPZoteroItem*)item;
-(void) writeItemFieldsToDatabase:(ZPZoteroItem*)item;

// These remove items from the cache
- (void) removeItemsNotInArray:(NSArray*)itemKeys fromCollection:(NSString*)collectionKey inLibrary:(NSNumber*)libraryID;
- (void) deleteItemsNotInArray:(NSArray*)itemKeys fromLibrary:(NSNumber*)libraryID;

- (void) setUpdatedTimeStampForCollection:(NSString*)collectionKey toValue:(NSString*)updatedTimeStamp;
- (void) setUpdatedTimeStampForLibrary:(NSNumber*)libraryID toValue:(NSString*)updatedTimeStamp;

@end
