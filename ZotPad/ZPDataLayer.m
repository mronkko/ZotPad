//
//  ZPDataLayer.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPDataLayer.h"
#import "ZPNavigatorNode.h"
#import "ZPServerConnection.h"

@implementation ZPDataLayer

static ZPDataLayer* _instance = nil;


-(id)init
{
    self = [super init];
	NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"zotpad.sqlite"];
    
    //Delete the file if it exists. This is just to always start with an empty cache while developing.
    NSError* error;
    [[NSFileManager defaultManager] removeItemAtPath: dbPath error:&error];
    NSLog(error);
    
	//TODO: Check if this is the apprpriate way to handle errors in Objective C 
	NSAssert((sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK), @"Failed to open the database");
   
    
    
    //Read the database structure from file and create the database
    
    NSString *sqlFile = [NSString stringWithContentsOfFile:[[NSBundle mainBundle]
                                                            pathForResource:@"database"
                                                            ofType:@"sql"]];
    
    NSArray *sqlStatements = [sqlFile componentsSeparatedByString:@";"];
    
    NSEnumerator *e = [sqlStatements objectEnumerator];
    id object;
    while (object = [e nextObject]) {
        [self executeStatement:object];
    }
    
    _collectionsSynced = FALSE;
    
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
 Updates the local cache for libraries and collections and retrieves this data from the server
 */

-(void) updateLibrariesAndCollectionsFromServer{

    NSLog(@"Loading group library information from server");
    NSArray* libraries = [[ZPServerConnection instance] retrieveLibrariesFromServer];
 
    //Library IDs are stored on the server, so we can just drop the content of the library table and recreate it

    [self executeStatement:@"DELETE FROM groups"];
    
    NSEnumerator* e = [libraries objectEnumerator];
    
    id library;
    
    while ( library = [e nextObject]) {
        
        NSString* libraryIDString =(NSString*)[(NSDictionary*) library objectForKey:@"id"];
                             
        
        [self executeStatement:[NSString stringWithFormat:@"INSERT INTO groups (groupID, name) VALUES (%@, '%@')",
                                libraryIDString,[(NSDictionary*) library objectForKey:@"title"]]];
                          
        NSLog([NSString stringWithFormat:@"Loading collections for group library '%@' from server",[(NSDictionary*) library objectForKey:@"title"]]);
        
        NSArray* collections = [[ZPServerConnection instance] retrieveCollectionsForLibraryFromServer:[libraryIDString intValue]];
        
        NSEnumerator* e2 = [collections objectEnumerator];
        id collection;
        while( collection =[e2 nextObject]){
            
            [self executeStatement:[NSString stringWithFormat:@"INSERT INTO collections (collectionName, key, libraryID, parentCollectionKey) VALUES ('%@','%@',%@,'%@')",
                                    [(NSDictionary*) collection objectForKey:@"title"],[(NSDictionary*) collection objectForKey:@"id"],
                                    libraryIDString,[(NSDictionary*) collection objectForKey:@"parentID"]]];    
        
        }
    }
    
    //Collections for My Library
    
    NSArray* collections = [[ZPServerConnection instance] retrieveCollectionsForLibraryFromServer:NULL];
    
    NSEnumerator* e2 = [collections objectEnumerator];
    id collection;
    while( collection =[e2 nextObject]){
        
        [self executeStatement:[NSString stringWithFormat:@"INSERT INTO collections (collectionName, key, parentCollectionKey) VALUES ('%@','%@','%@')",
                                [(NSDictionary*) collection objectForKey:@"title"],[(NSDictionary*) collection objectForKey:@"id"],
                                [(NSDictionary*) collection objectForKey:@"parentID"]]];    
        
    }

    // Resolve parent IDs based on parent keys
    // A nested subquery is needed to rename columns because SQLite does not support table aliases in update statement

    [self executeStatement:@"UPDATE collections SET parentCollectionID = (SELECT A FROM (SELECT collectionID as A, key AS B FROM collections) WHERE B=parentCollectionKey)"];
    
    
    //TODO: Delete orhpaned collections and items if a library was deleted 

}

/*
 
 Returns an array containing all libraries  
 
 */

- (NSArray*) libraries {
	
    //If we have not updated with server yet, do so
    if(! _collectionsSynced & [[ZPServerConnection instance] authenticated]){
        [self updateLibrariesAndCollectionsFromServer];
    }
    

    NSMutableArray *returnArray = [[NSMutableArray alloc] init];
    
    //Check if there are collections in my library
    
    sqlite3_stmt *selectstmt = [self prepareStatement:@"SELECT collectionID FROM collections WHERE libraryID IS NULL LIMIT 1"];
	
	
	
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
    
	 selectstmt = [self prepareStatement:@"SELECT groupID, name, groupID IN (SELECT DISTINCT libraryID from collections) AS hasChildren FROM groups"];
		
    
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
    
	sqlite3_stmt *selectstmt = [self prepareStatement:[NSString stringWithFormat: @"SELECT collectionID, collectionName, collectionID IN (SELECT DISTINCT parentCollectionID FROM collections WHERE %@) AS hasChildren FROM collections WHERE %@ AND %@",libraryCondition,libraryCondition,collectionCondition ]];
	
    
	
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
    
    
	sqlite3_stmt *selectstmt = [self prepareStatement:baseSQL];
	
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
 
    sqlite3_stmt *selectstmt = [self prepareStatement:[NSString stringWithFormat: @"SELECT fieldName, value FROM itemData, fields, itemDataValues WHERE itemData.itemID = %i AND itemData.fieldID = fields.fieldID AND itemData.valueID = itemDataValues.valueID",itemID]];
	
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
    
    sqlite3_stmt *selectstmt = [self prepareStatement:[NSString stringWithFormat: @"SELECT firstName, lastName FROM itemCreators, creators, creatorData WHERE itemCreators.itemID = %i AND itemCreators.creatorID = creators.creatorID AND creators.creatorDataID = creatorData.creatorDataID ORDER BY itemCreators.orderIndex ASC",itemID]];
	
    

	NSMutableArray* returnArray = [[NSMutableArray alloc] init];
    
	while(sqlite3_step(selectstmt) == SQLITE_ROW) {
		
		
		NSString *creatorName = [NSString stringWithFormat:@"%s, %s", sqlite3_column_text(selectstmt, 1), sqlite3_column_text(selectstmt, 0)];
        
        [returnArray addObject:creatorName];
	}
	
	sqlite3_finalize(selectstmt);
	
	return returnArray;
}

- (NSArray*) getAttachmentFilePathsForItem: (NSInteger) itemID{
        
    sqlite3_stmt *selectstmt =[self prepareStatement:[NSString stringWithFormat: @"SELECT key, path FROM itemAttachments ia, items i WHERE ia.sourceItemID=%i AND ia.linkMode=1 AND ia.mimeType='application/pdf' AND i.itemID=ia.itemID;",itemID]];
        
        
    
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

-(sqlite3_stmt*) prepareStatement:(NSString*) sqlString{

    const char *errmsg;
    
    sqlite3_stmt *selectstmt;
    
    if(sqlite3_prepare_v2(database,[sqlString UTF8String],-1, &selectstmt,&errmsg) != SQLITE_OK){
        NSLog(sqlString);
        NSLog([NSString stringWithUTF8String:errmsg]);
    }
    
    return selectstmt;
}

-(void) executeStatement:(NSString*) sqlString{
    
    char *errmsg;
    
    if(sqlite3_exec(database,[sqlString UTF8String],NULL,NULL,&errmsg) != SQLITE_OK){
        NSLog(sqlString);
        NSLog([NSString stringWithUTF8String:errmsg]);
    }
}


@end
