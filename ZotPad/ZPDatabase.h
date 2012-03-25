//
//  ZPDatabase.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroItem.h"
#import "ZPZoteroNote.h"
#import "ZPZoteroAttachment.h"
#import "ZPZoteroLibrary.h"
#import "ZPZoteroCollection.h"

#import "../FMDB/src/FMDatabase.h"
#import "../FMDB/src/FMResultSet.h"

@interface ZPDatabase : NSObject{
     
    FMDatabase* _database;
}

// This class is used as a singleton
+ (ZPDatabase*) instance;


-(void) resetDatabase;

/*
 
 Methods for reading from DB
 
 */



// Methods for retrieving data from the data layer
- (NSArray*) groupLibraries;
- (NSArray*) collectionsForLibrary : (NSNumber*)currentlibraryID withParentCollection:(NSString*)currentCollectionKey;
- (NSArray*) collectionsForLibrary : (NSNumber*)currentlibraryID;


// Methods for retrieving item keys
- (NSArray*) getItemKeysForLibrary:(NSNumber*)libraryID collectionKey:(NSString*)collectionKey
                      searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending;

- (NSString*) getFirstItemKeyWithTimestamp:(NSString*)timestamp from:(NSNumber*)libraryID;


// Methods for filling data into existing objects
- (void) addAttributesToGroupLibrary:(ZPZoteroLibrary*) library;
- (void) addAttributesToCollection:(ZPZoteroCollection*) collection;
- (NSDictionary*) attributesForItemWithKey:(NSString *)key;


- (void) addCreatorsToItem: (ZPZoteroItem*) item;
- (void) addFieldsToItem: (ZPZoteroItem*) item;
- (void) addNotesToItem: (ZPZoteroItem*) item;
- (void) addAttachmentsToItem: (ZPZoteroItem*) item;

//Return a list of all attachment paths ordered by priority for removel
- (NSArray*) getCachedAttachmentsOrderedByRemovalPriority;

//Return a list of all attachment paths priority for retrieval
- (NSArray*) getAttachmentsInLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey;

- (NSString*) getLocalizationStringWithKey:(NSString*) key type:(NSString*) type locale:(NSString*) locale;

// Retrieves all item keys and note and attachment keys from the library

- (NSArray*) getAllItemKeysForLibrary:(NSNumber*)libraryID;


- (NSArray*) collectionsForItem:(ZPZoteroItem*)item;
    
/*
 
 Methods for writing to DB

 */

// Methods for writing data to database
// These take an array of ZPZotero* objects instead of a single objects because batch editing or inserting results in a significant performance boost

- (void) writeLibraries:(NSArray*)libraries;
- (void) writeCollections:(NSArray*)collections toLibrary:(ZPZoteroLibrary*)library;

// This method returns an array containing the items that were actually modified in the DB. This can be used to determine if fields and attachments
// need to be modified

-(NSArray*) writeItems:(NSArray*)items;
-(NSArray*) writeNotes:(NSArray*)notes;
-(NSArray*) writeAttachments:(NSArray*)attachments;

-(void) writeItems:(NSArray*)items toCollection:(NSString*)collectionKey;
-(void) addItemKeys:(NSArray*)keys toCollection:(NSString*)collectionKey;

-(void) writeItemsCreators:(NSArray*)items;
-(void) writeItemsFields:(NSArray*)items;


// These remove items from the cache
- (void) removeItemKeysNotInArray:(NSArray*)itemKeys fromCollection:(NSString*)collectionKey;
- (void) deleteItemKeysNotInArray:(NSArray*)itemKeys fromLibrary:(NSNumber*)libraryID;

- (void) updateViewedTimestamp:(ZPZoteroAttachment*)attachment;
- (void) setUpdatedTimestampForCollection:(NSString*)collectionKey toValue:(NSString*)updatedTimestamp;
- (void) setUpdatedTimestampForLibrary:(NSNumber*)libraryID toValue:(NSString*)updatedTimestamp;

@end
