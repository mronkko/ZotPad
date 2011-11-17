//
//  ZPDataLayer.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPDataLayer.h"
#import "ZPNavigatorNode.h"


@implementation ZPDataLayer

static ZPDataLayer* _instance = nil;


-(id)init
{
    self = [super init];
	NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"zotero.sqlite"];
    
	//TODO: Check if this is the apprpriate way to handle errors in Objective C 
	NSAssert((sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK), @"Failed to open the database");
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
 
 Returns an array containing all libraries  
 
 */

- (NSArray*) libraries {
	
	sqlite3_stmt *selectstmt;

    NSMutableArray *returnArray = [[NSMutableArray alloc] init];
    
    //Check if there are collections in my library
    const char *sqlmy = [@"SELECT collectionID FROM collections WHERE libraryID IS NULL LIMIT 1" UTF8String];
	
	sqlite3_prepare_v2(database, sqlmy,-1, &selectstmt, NULL);
	
	NSInteger libraryID = 1;
	NSString* name = @"My Library";
    BOOL hasChildren  =sqlite3_step(selectstmt) == SQLITE_ROW;
       
	ZPNavigatorNode* thisLibrary = [[ZPNavigatorNode alloc] init];
    [thisLibrary setLibraryID : libraryID];
	[thisLibrary setName : name];
    [thisLibrary setHasChildren:hasChildren];
	[returnArray addObject:thisLibrary];
	
	sqlite3_finalize(selectstmt);

    //Group libraries
    
	const char *sqlgroup = [@"SELECT libraryID, name, libraryID IN (SELECT DISTINCT libraryID from collections) AS hasChildren FROM groups" UTF8String];
	
	sqlite3_prepare_v2(database, sqlgroup,-1, &selectstmt, NULL);
		
    
	while(sqlite3_step(selectstmt) == SQLITE_ROW) {
		
		NSInteger libraryID = sqlite3_column_int(selectstmt, 0);
		NSString* name = [[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(selectstmt, 1)];
        BOOL hasChildren = sqlite3_column_int(selectstmt, 2);

		ZPNavigatorNode* thisLibrary = [[ZPNavigatorNode alloc] init];
        [thisLibrary setLibraryID : libraryID];
		[thisLibrary setName : name];
		[thisLibrary setHasChildren:hasChildren];
        
		[returnArray addObject:thisLibrary];
	}
	
	sqlite3_finalize(selectstmt);
	
	return returnArray;
}

/*
 
 Returns an array containing all libraries with their collections 
 
 */

- (NSArray*) collections : (NSInteger)currentLibraryID currentCollection:(NSInteger)currentCollectionID {
	

    NSString* libraryCondition;
    NSString* collectionCondition;
    
    //My library is coded as 1 in ZotPad and is NULL in the database.
    
    if(currentLibraryID == 1){
        libraryCondition = @"libraryID IS NULL";
    }
    else{
        libraryCondition = [NSString stringWithFormat:@"libraryID = %i",currentLibraryID];
    }

    if(currentCollectionID == 0){
        collectionCondition= @"parentCollectionID IS NULL";
    }
    else{
        collectionCondition = [NSString stringWithFormat:@"parentCollectionID = %i",currentCollectionID];
    }
    
	sqlite3_stmt *selectstmt;
	
	const char *sql = [[NSString stringWithFormat: @"SELECT collectionID, collectionName, collectionID IN (SELECT DISTINCT parentCollectionID FROM collections WHERE %@) AS hasChildren FROM collections WHERE %@ AND %@",libraryCondition,libraryCondition,collectionCondition ] UTF8String];
	
    
	sqlite3_prepare_v2(database, sql,-1, &selectstmt, NULL);
	
	
	NSMutableArray *returnArray = [[NSMutableArray alloc] init];
    
	while(sqlite3_step(selectstmt) == SQLITE_ROW) {
		
		NSInteger collectionID = sqlite3_column_int(selectstmt, 0);
		NSString *name = [[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(selectstmt, 1)];
        BOOL hasChildren = sqlite3_column_int(selectstmt, 2);
        
		ZPNavigatorNode* thisCollection = [[ZPNavigatorNode alloc] init];
        [thisCollection setLibraryID : currentLibraryID];
        [thisCollection setCollectionID : collectionID];
		[thisCollection setName : name];
		[thisCollection setHasChildren:hasChildren];
        
		[returnArray addObject:thisCollection];

	}
	
	sqlite3_finalize(selectstmt);
	
	return returnArray;
}

/*
 Returns an array of item IDs corresponding to the currently selected collection, library, search criteria and sort criteria.
 */

- (NSArray*) getItemIDsForView:(ZPDetailViewController*)view {

    NSString* baseSQL;
    
    //My library is coded as 1 in ZotPad and is NULL in the database.
    
    //Attachments have itemType 14, so exclude these
    
    if([view collectionID] == 0){
        if([view libraryID] == 1){
            baseSQL = @"SELECT itemID FROM items WHERE libraryID IS NULL AND itemTypeID <> 14";
        }
        else{
            baseSQL = [NSString stringWithFormat: @"SELECT itemID FROM items WHERE libraryID = %i AND itemTypeID <> 14",[view libraryID]];
        }
    }
    else{
        //TODO: Exclude attachments here 
         baseSQL = [NSString stringWithFormat: @"SELECT itemID FROM collectionItems WHERE collectionID = %i ",[view collectionID]];
    }
    
    
	sqlite3_stmt *selectstmt;
	
	const char *sql = [baseSQL UTF8String];
	
    
	sqlite3_prepare_v2(database, sql,-1, &selectstmt, NULL);
	
	
	NSMutableArray *returnArray = [[NSMutableArray alloc] init];
    
	while(sqlite3_step(selectstmt) == SQLITE_ROW) {
		
		[returnArray addObject:[NSNumber numberWithInteger:sqlite3_column_int(selectstmt, 0)]];
        
	}
	
	sqlite3_finalize(selectstmt);
	
	return returnArray;

}

/*
 Returns the  fields for an item as a dictionary
 */

- (NSDictionary*) getFieldsForItem: (NSInteger) itemID  {
 
    sqlite3_stmt *selectstmt;
	
	const char *sql = [[NSString stringWithFormat: @"SELECT fieldName, value FROM itemData, fields, itemDataValues WHERE itemData.itemID = %i AND itemData.fieldID = fields.fieldID AND itemData.valueID = itemDataValues.valueID",itemID] UTF8String];
	
    // NSLog([NSString stringWithUTF8String:sql]);

    
	sqlite3_prepare_v2(database, sql,-1, &selectstmt, NULL);
	
	
	NSMutableDictionary* returnDictionary = [[NSMutableDictionary alloc] init];
    
	while(sqlite3_step(selectstmt) == SQLITE_ROW) {
		
		
		NSString *key = [[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(selectstmt, 0)];
        NSString *value = [[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(selectstmt, 1)];
        
        [returnDictionary setObject:value forKey:key];
	}
	
	sqlite3_finalize(selectstmt);
	
	return returnDictionary;
}

/*
 Returns the creators (i.e. authors) for an item
 
 */

- (NSArray*) getCreatorsForItem: (NSInteger) itemID  {
    
    sqlite3_stmt *selectstmt;
	
	const char *sql = [[NSString stringWithFormat: @"SELECT firstName, lastName FROM itemCreators, creators, creatorData WHERE itemCreators.itemID = %i AND itemCreators.creatorID = creators.creatorID AND creators.creatorDataID = creatorData.creatorDataID ORDER BY itemCreators.orderIndex ASC",itemID] UTF8String];
	
    
    // NSLog([NSString stringWithUTF8String:sql]);

    sqlite3_prepare_v2(database, sql,-1, &selectstmt, NULL);
	
	
	NSMutableArray* returnArray = [[NSMutableArray alloc] init];
    
	while(sqlite3_step(selectstmt) == SQLITE_ROW) {
		
		
		NSString *creatorName = [NSString stringWithFormat:@"%s, %s", sqlite3_column_text(selectstmt, 1), sqlite3_column_text(selectstmt, 0)];
        
        [returnArray addObject:creatorName];
	}
	
	sqlite3_finalize(selectstmt);
	
	return returnArray;
}

- (NSArray*) getAttachmentFilePathsForItem: (NSInteger) itemID{
        
    sqlite3_stmt *selectstmt;
        
    const char *sql = [[NSString stringWithFormat: @"SELECT key, path FROM itemAttachments ia, items i WHERE ia.sourceItemID=%i AND ia.linkMode=1 AND ia.mimeType='application/pdf' AND i.itemID=ia.itemID;",itemID] UTF8String];
        
        
    NSLog([NSString stringWithUTF8String:sql]);
        
    sqlite3_prepare_v2(database, sql,-1, &selectstmt, NULL);
        
      
    
    NSMutableArray* returnArray = [[NSMutableArray alloc] init];
    
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];

        
    while(sqlite3_step(selectstmt) == SQLITE_ROW) {
            
        //Remove the storage: from the beginning of the filename
        NSString *attachmentPath = [NSString stringWithFormat:@"%@/storage/%s/%@", documentsDirectory, sqlite3_column_text(selectstmt, 0), [[[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(selectstmt, 1)]substringFromIndex: 8]];
        
        NSLog(attachmentPath);
        
        [returnArray addObject:attachmentPath];
    }
        
    sqlite3_finalize(selectstmt);
        
    return returnArray;
}    

@end
