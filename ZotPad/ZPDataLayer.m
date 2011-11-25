//
//  ZPDataLayer.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

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


@implementation ZPDataLayer

static ZPDataLayer* _instance = nil;

//TODO: Convert this to use prepared statements and binding
//TODO: move all database related things to a new class and isolate the use of sqlite3 funtions to as few funtions as possible to isolate memory management problems

-(id)init
{
    self = [super init];
	NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"zotpad.sqlite"];
    
    //Delete the file if it exists. This is just to always start with an empty cache while developing.
    NSError* error;
    [[NSFileManager defaultManager] removeItemAtPath: dbPath error:&error];
    NSLog(@"%@",error);
    
	//TODO: Check if this is the apprpriate way to handle errors in Objective C 
	NSAssert((sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK), @"Failed to open the database");
   
    
    
    //Read the database structure from file and create the database
    
    NSStringEncoding encoding;
    
    NSString *sqlFile = [NSString stringWithContentsOfFile:[[NSBundle mainBundle]
                                                            pathForResource:@"database"
                                                            ofType:@"sql"] usedEncoding:&encoding error:&error];
    
    NSArray *sqlStatements = [sqlFile componentsSeparatedByString:@";"];
    
    NSEnumerator *e = [sqlStatements objectEnumerator];
    id object;
    while (object = [e nextObject]) {
        [self executeStatement:object];
    }
    
    //Initialize OperationQueues for retrieving data from server and writing it to cache
    _itemRetrieveQueue = [[NSOperationQueue alloc] init];
    _itemCacheWriteQueue = [[NSOperationQueue alloc] init];
    
    _collectionTreeCached = FALSE;
    _collectionCacheStatus = [[NSMutableDictionary alloc] init];
    
    _debugDatabase = FALSE;
    
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


/*
 Updates the local cache for libraries and collections and retrieves this data from the server
 */

-(void) updateLibrariesAndCollectionsFromServer{

    NSLog(@"Loading group library information from server");
    NSArray* libraries = [[ZPServerConnection instance] retrieveLibrariesFromServer];
 
    //Library IDs are stored on the server, so we can just drop the content of the library table and recreate it

    [self executeStatement:@"DELETE FROM groups"];
    
    NSEnumerator* e = [libraries objectEnumerator];
    
    ZPZoteroLibrary* library;
    
    while ( library = (ZPZoteroLibrary*) [e nextObject]) {
        
        [self executeStatement:[NSString stringWithFormat:@"INSERT INTO groups (groupID, name) VALUES (%i, '%@')",
                                library.libraryID,library.name]];
                          
        NSLog(@"Loading collections for group library '%@' from server",library.name);
        
        NSArray* collections = [[ZPServerConnection instance] retrieveCollectionsForLibraryFromServer:library.libraryID];
        
        NSEnumerator* e2 = [collections objectEnumerator];

        ZPZoteroCollection* collection;
        while( collection =(ZPZoteroCollection*)[e2 nextObject]){
            
            NSString* parent;
            
            if(collection.parentCollectionKey == NULL){
                parent=@"NULL";
            }
            else{
                parent = [NSString stringWithFormat:@"'%@'",collection.parentCollectionKey];
            }

            [self executeStatement:[NSString stringWithFormat:@"INSERT INTO collections (collectionName, key, libraryID, parentCollectionKey) VALUES ('%@','%@',%i,%@)",collection.name,collection.collectionKey,library.libraryID,parent]];
                                    
        
        }
    }
    
    //Collections for My Library
    
    NSArray* collections = [[ZPServerConnection instance] retrieveCollectionsForLibraryFromServer:1];
    
    NSEnumerator* e2 = [collections objectEnumerator];
    
    ZPZoteroCollection* collection;
    while( collection =(ZPZoteroCollection*)[e2 nextObject]){
        
        NSString* parent;
        
        if(collection.parentCollectionKey == NULL){
            parent=@"NULL";
        }
        else{
            parent = [NSString stringWithFormat:@"'%@'",collection.parentCollectionKey];
        }
        [self executeStatement:[NSString stringWithFormat:@"INSERT INTO collections (collectionName, key, parentCollectionKey) VALUES ('%@','%@',%@)",
                               collection.name,collection.collectionKey,parent]];    
        
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
    if(! _collectionTreeCached & [[ZPServerConnection instance] authenticated]){
        [self updateLibrariesAndCollectionsFromServer];
    }
    

    NSMutableArray *returnArray = [[NSMutableArray alloc] init];
    
       
	ZPZoteroLibrary* thisLibrary = [[ZPZoteroLibrary alloc] init];
    [thisLibrary setLibraryID : 1];
	[thisLibrary setTitle: @"My Library"];
    
    //Check if there are collections in my library
    
    sqlite3_stmt* selectstmt = [self prepareStatement:@"SELECT collectionID FROM collections WHERE libraryID IS NULL LIMIT 1"];
	BOOL hasChildren  =sqlite3_step(selectstmt) == SQLITE_ROW;
    
    [thisLibrary setHasChildren:hasChildren];
	[returnArray addObject:thisLibrary];
	
	sqlite3_finalize(selectstmt);

    //Group libraries
    
	 selectstmt = [self prepareStatement:@"SELECT groupID, name, groupID IN (SELECT DISTINCT libraryID from collections) AS hasChildren FROM groups"];
		
    
	while(sqlite3_step(selectstmt) == SQLITE_ROW) {
		
		NSInteger libraryID = sqlite3_column_int(selectstmt, 0);
		NSString* name = [[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(selectstmt, 1)];
        BOOL hasChildren = sqlite3_column_int(selectstmt, 2);

        ZPZoteroLibrary* thisLibrary = [[ZPZoteroLibrary alloc] init];
        [thisLibrary setLibraryID : libraryID];
        [thisLibrary setName: name];
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
        
		ZPZoteroCollection* thisCollection = [[ZPZoteroCollection alloc] init];
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
 
 Creates an array that will hold the item IDs of the current view. Initially contains only 15 first
    IDs with the rest of the item ids set to 0 and populated later in the bacground.

 */


- (NSArray*) getItemKeysForView:(ZPDetailViewController*)view{
    
    //If we have an ongoing item retrieval in teh background, tell it that it can stop
    

    [_mostRecentItemRetrieveOperation markAsNotWithActiveView];
    
    
    NSString* collectionKey = NULL;
    if(view.collectionID!=0){
      collectionKey = [self collectionKeyFromCollectionID:view.collectionID];
    }
    _currentlyActiveCollectionKey = collectionKey;
    
    NSString* searchString = [view.searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // Start by deciding if we need to connect to the server or can use cache. We can rely on cache if this collection is completely cached already
    // Check the possible values from the header file
    
    NSNumber* cacheStatus = [_collectionCacheStatus objectForKey:[NSNumber numberWithInt:view.collectionID]];
    
    if( cacheStatus == NULL || [cacheStatus intValue] != 2 ){
        
               
        //Retrieve initial 15 items
        
        ZPServerResponseXMLParser* parserResults = [[ZPServerConnection instance] retrieveItemsFromLibrary:view.libraryID collection:collectionKey searchString:searchString sortField:view.sortField sortDescending:view.sortIsDescending limit:15 start:0];
        
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
        
        [self cacheZoteroItems:[parserResults parsedElements]];
        
        //Retrieve the rest of the items into the array
        ZPItemRetrieveOperation* retrieveOperation = [[ZPItemRetrieveOperation alloc] initWithArray: returnArray library:view.libraryID collection:collectionKey searchString:searchString sortField:view.sortField sortDescending:view.sortIsDescending queue:_itemRetrieveQueue];
        
       
         
        //If this is the first time that we are using this collection, mark this operation as a cache operation if it does not have a search string or create a new operations without a search string
        if([cacheStatus intValue] != 1){
            if (searchString== NULL || [searchString isEqualToString:@""] ){
                [retrieveOperation markAsInitialRequestForCollection];
                [_itemRetrieveQueue addOperation:retrieveOperation];
            }
            else{
                [_itemRetrieveQueue addOperation:retrieveOperation];
                
                //Start a new backround operation to retrieve all items in the colletion (the main request was filtered with sort)
                ZPItemRetrieveOperation* retrieveOperationForCache = [[ZPItemRetrieveOperation alloc] initWithArray: [NSArray array] library:view.libraryID collection:collectionKey searchString:NULL sortField:NULL sortDescending:NO queue:_itemRetrieveQueue];
                [retrieveOperationForCache markAsInitialRequestForCollection];
                [_itemRetrieveQueue addOperation:retrieveOperationForCache];
            }
            // Mark that we have started retrieving things from the server 
            [_collectionCacheStatus setValue:[NSNumber numberWithInt:1] forKey:[NSString stringWithFormat:@"%i", view.collectionID]];
        }
        
        
        return returnArray;

    }
    // Retrieve itemIDs from cache
    else{
        return NULL;
    }
    
    
    return NULL;
    
}

-(NSString*) collectionKeyFromCollectionID:(NSInteger)collectionID{
    //TODO: This could be optimized by loading the results in an array or dictionary instead of retrieving them from the database over and over 
    sqlite3_stmt *selectstmt = [self prepareStatement:[NSString stringWithFormat: @"SELECT key FROM collections WHERE collectionID = %i LIMIT 1",collectionID]];
    sqlite3_step(selectstmt);
    return [NSString stringWithUTF8String:(char *)sqlite3_column_text(selectstmt, 0)];
}

-(void) cacheZoteroItems:(NSArray*)items {
    ZPItemCacheWriteOperation* cacheWriteOperation = [[ZPItemCacheWriteOperation alloc] initWithZoteroItemArray:items];
    [_itemCacheWriteQueue addOperation:cacheWriteOperation];
}

/*
 
 Writes an item to the database if it does not already exist.
 
 //TODO: Convert this to a function taking array as input and then using one prepared statement for all insert.
 
 */

-(void) addItemToDatabase:(ZPZoteroItem*)item {
    
    //TODO: Implement modifying already existing items if they are older than the new item
    sqlite3_stmt *selectstmt = [self prepareStatement:[NSString stringWithFormat: @"SELECT dateModified, itemID FROM items WHERE key ='%@' LIMIT 1",item.key]];

    if(sqlite3_step(selectstmt) != SQLITE_ROW){
        //TODO: implement item types
        //TODO: implement dateModified
        
        NSString* year;
        if(item.year!=0){
            year=[NSString stringWithFormat:@"%i",item.year];
        }
        else{
            year=@"NULL";
        }

        sqlite3_stmt *insertstmt = [self prepareStatement:[NSString stringWithFormat: @"INSERT INTO items (itemTypeID,libraryID,year,authors,title,publishedIn,key) VALUES (0,%i,%@,?,?,?,?)",item.libraryID,year,item.key]];
        
        //Bind parameters
        sqlite3_bind_text(insertstmt,1,[item.authors UTF8String],-1,NULL);
        sqlite3_bind_text(insertstmt,2,[item.title UTF8String],-1,NULL);
        sqlite3_bind_text(insertstmt,3,[item.publishedIn UTF8String],-1,NULL);
        sqlite3_bind_text(insertstmt,4,[item.key UTF8String],-1,NULL);
        
        sqlite3_step(insertstmt);
        sqlite3_finalize(insertstmt);

    }
}

- (ZPZoteroItem*) getItemByKey: (NSString*) key{
    sqlite3_stmt *selectstmt = [self prepareStatement:[NSString stringWithFormat: @"SELECT itemTypeID,libraryID,year,authors,title,publishedIn,key FROM items WHERE key='%@' LIMIT 1",key]];
    
	ZPZoteroItem* item;
    
	if (sqlite3_step(selectstmt) == SQLITE_ROW) {
        
        item = [[ZPZoteroItem alloc] init];
        //TODO: Implement item type
        [item setLibraryID:sqlite3_column_int(selectstmt, 1)];
        [item setYear:sqlite3_column_int(selectstmt, 2)];
        if(sqlite3_column_text(selectstmt, 3)!=NULL)
            [item setAuthors:[NSString stringWithFormat:@"%s",sqlite3_column_text(selectstmt, 3)]];
        [item setTitle:[NSString stringWithFormat:@"%s",sqlite3_column_text(selectstmt, 4)]];
        if(sqlite3_column_text(selectstmt, 5)!=NULL)
            [item setPublishedIn:[NSString stringWithFormat:@"%s",sqlite3_column_text(selectstmt, 5)]];
        [item setKey:[NSString stringWithFormat:@"%s",sqlite3_column_text(selectstmt, 6)]];
	}
    
	sqlite3_finalize(selectstmt);
    
    return item;
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


- (NSArray*) getAttachmentFilePathsForItem: (NSInteger) itemID{
        
    sqlite3_stmt *selectstmt =[self prepareStatement:[NSString stringWithFormat: @"SELECT key, path FROM itemAttachments ia, items i WHERE ia.sourceItemID=%i AND ia.linkMode=1 AND ia.mimeType='application/pdf' AND i.itemID=ia.itemID;",itemID]];
        
    
    NSMutableArray* returnArray = [[NSMutableArray alloc] init];
    
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];

        
    while(sqlite3_step(selectstmt) == SQLITE_ROW) {
            
        //Remove the storage: from the beginning of the filename
        NSString *attachmentPath = [NSString stringWithFormat:@"%@/storage/%s/%@", documentsDirectory, sqlite3_column_text(selectstmt, 0), [[[NSString alloc] initWithUTF8String:(const char *) sqlite3_column_text(selectstmt, 1)]substringFromIndex: 8]];
        
        NSLog(@"%@",attachmentPath);
        
        [returnArray addObject:attachmentPath];
    }
        
    sqlite3_finalize(selectstmt);
        
    return returnArray;
}    

-(sqlite3_stmt*) prepareStatement:(NSString*) sqlString{

    const char *errmsg = NULL;
    
    sqlite3_stmt *selectstmt = NULL;
    
     if(_debugDatabase) NSLog(@"%@",sqlString);
    
    if(sqlite3_prepare_v2(database,[sqlString UTF8String],-1, &selectstmt,&errmsg) != SQLITE_OK){
        if(!_debugDatabase) NSLog(@"%@",sqlString);
        NSLog(@"Database error: %@",[NSString stringWithUTF8String:errmsg]);
    }
    
    return selectstmt;
}

-(void) executeStatement:(NSString*) sqlString{
    
    char *errmsg;
    
    if(_debugDatabase) NSLog(@"%@",sqlString);
    
    if(sqlite3_exec(database,[sqlString UTF8String],NULL,NULL,&errmsg) != SQLITE_OK){
        if(!_debugDatabase) NSLog(@"%@",sqlString);
        NSLog(@"Database error: %@",[NSString stringWithUTF8String:errmsg]);
    }
}


@end
