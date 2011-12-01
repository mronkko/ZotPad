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

//DB library
#import "../FMDB/src/FMDatabase.h"
#import "../FMDB/src/FMResultSet.h"


@implementation ZPDataLayer

static ZPDataLayer* _instance = nil;


-(id)init
{
    self = [super init];
    
    _debugDataLayer = FALSE;
    
	NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"zotpad.sqlite"];
    

    NSError* error;
    
    /*
    //Delete the file if it exists. This is just to always start with an empty cache while developing.
    [[NSFileManager defaultManager] removeItemAtPath: dbPath error:&error];
    NSLog(@"%@",error);
    */
    
    _database = [FMDatabase databaseWithPath:dbPath];
    [_database open];
    [_database setTraceExecution:_debugDataLayer];
    
    //Read the database structure from file and create the database
    
    NSStringEncoding encoding;
    
    NSString *sqlFile = [NSString stringWithContentsOfFile:[[NSBundle mainBundle]
                                                            pathForResource:@"database"
                                                            ofType:@"sql"] usedEncoding:&encoding error:&error];
    
    NSArray *sqlStatements = [sqlFile componentsSeparatedByString:@";"];
    
    NSEnumerator *e = [sqlStatements objectEnumerator];
    id sqlString;
    while (sqlString = [e nextObject]) {
        [_database executeQuery:sqlString];
    }
    
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
 
    //Library IDs are stored on the server, so we can just drop the content of the library table and recreate it
    
    @synchronized(self){
        [_database executeUpdate:@"DELETE FROM groups"];
    }
    //Collections IDs are not stored in the server, but are local and because of this we cannot juts drop the collections.
    //Retrieve a list of collection keys so that we know which collections already exist
    
    
    NSMutableArray* collectionKeys;
    
    @synchronized(self){
        FMResultSet* resultSet=[_database executeQuery:@"SELECT key FROM collections"];

        collectionKeys =[[NSMutableArray alloc] init];

        while([resultSet next]){
            [collectionKeys addObject:[resultSet stringForColumnIndex:0]];
        }
    }
    
    NSEnumerator* e = [libraries objectEnumerator];
    
    ZPZoteroLibrary* library;
    
    while ( library = (ZPZoteroLibrary*) [e nextObject]) {
        
        NSNumber* libraryID = [NSNumber numberWithInt:library.libraryID];
        @synchronized(self){
            [_database executeUpdate:@"INSERT INTO groups (groupID, name) VALUES (?, ?)",libraryID,library.name];
        }  
        
        NSLog(@"Loading collections for group library '%@' from server",library.name);
        
        NSArray* collections = [[ZPServerConnection instance] retrieveCollectionsForLibraryFromServer:library.libraryID];
        
        NSEnumerator* e2 = [collections objectEnumerator];

        ZPZoteroCollection* collection;
        while( collection =(ZPZoteroCollection*)[e2 nextObject]){
            
            //Insert or update
            NSInteger count= [collectionKeys count];
            [collectionKeys removeObject:collection.collectionKey];
            
            NSNumber* libraryID = [NSNumber numberWithInt:library.libraryID];
            
            @synchronized(self){
                if(count == [collectionKeys count]){

                    [_database executeUpdate:@"INSERT INTO collections (collectionName, key, libraryID, parentCollectionKey) VALUES (?,?,?,?)",collection.name,collection.collectionKey,libraryID,collection.parentCollectionKey];
                }
                else{
                    [_database executeUpdate:@"UPDATE collections SET collectionName=?, libraryID=?, parentCollectionKey=? WHERE key=?",collection.name,libraryID,collection.parentCollectionKey ,collection.collectionKey];
                }
            }
        
        }
    }
    
    //Collections for My Library
    
    NSArray* collections = [[ZPServerConnection instance] retrieveCollectionsForLibraryFromServer:1];
    
    NSEnumerator* e2 = [collections objectEnumerator];
    
    ZPZoteroCollection* collection;
    while( collection =(ZPZoteroCollection*)[e2 nextObject]){
        
        //Insert or update
        NSInteger count= [collectionKeys count];
        [collectionKeys removeObject:collection.collectionKey];
        
        @synchronized(self){
            if(count == [collectionKeys count]){
            
                [_database executeUpdate:@"INSERT INTO collections (collectionName, key, parentCollectionKey) VALUES (?,?,?)",collection.name,collection.collectionKey,collection.parentCollectionKey ];
            }
            else{
                [_database executeUpdate:@"UPDATE collections SET collectionName=?, libraryID=NULL, parentCollectionKey=? WHERE key=?",collection.name,collection.parentCollectionKey ,collection.collectionKey];
            }
        }
    }

    // Delete collections that no longer exist
    
    NSEnumerator* e3 = [collectionKeys objectEnumerator];
    
    NSString* key;
    while( key =(NSString*)[e3 nextObject]){
        @synchronized(self){
            [_database executeUpdate:@"DELETE FROM collections WHERE key=?)",key];
        }
    }
    
    // Resolve parent IDs based on parent keys
    // A nested subquery is needed to rename columns because SQLite does not support table aliases in update statement
    
    @synchronized(self){
        [_database executeUpdate:@"UPDATE collections SET parentCollectionID = (SELECT A FROM (SELECT collectionID as A, key AS B FROM collections) WHERE B=parentCollectionKey)"];
    }
    
    //TODO: Clean up orphaned items

}

/*
 
 Returns an array containing all libraries  
 
 */

- (NSArray*) libraries {
	
    NSMutableArray *returnArray = [[NSMutableArray alloc] init];
    
       
	ZPZoteroLibrary* thisLibrary = [[ZPZoteroLibrary alloc] init];
    [thisLibrary setLibraryID : 1];
	[thisLibrary setTitle: @"My Library"];
    
    //Check if there are collections in my library
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery:@"SELECT collectionID FROM collections WHERE libraryID IS NULL LIMIT 1"];
        BOOL hasChildren  =[resultSet next];
    
        [thisLibrary setHasChildren:hasChildren];
        [returnArray addObject:thisLibrary];
	}
    
    //Group libraries
    @synchronized(self){
    
        FMResultSet* resultSet = [_database executeQuery:@"SELECT groupID, name, groupID IN (SELECT DISTINCT libraryID from collections) AS hasChildren FROM groups"];
		
        
        while([resultSet next]) {
            
            NSInteger libraryID = [resultSet intForColumnIndex:0];
            NSString* name = [resultSet stringForColumnIndex:1];
            BOOL hasChildren = [resultSet boolForColumnIndex:2];
            
            ZPZoteroLibrary* thisLibrary = [[ZPZoteroLibrary alloc] init];
            [thisLibrary setLibraryID : libraryID];
            [thisLibrary setName: name];
            [thisLibrary setHasChildren:hasChildren];
            
            [returnArray addObject:thisLibrary];
        }
    }
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
        //Collection key is used here insted of collection ID because it is more reliable.
        collectionCondition= @"parentCollectionKey IS NULL";
    }
    else{
        collectionCondition = [NSString stringWithFormat:@"parentCollectionID = %i",currentCollectionID];
    }
    
    NSMutableArray* returnArray;
    
	@synchronized(self){
        FMResultSet* resultSet = [_database executeQuery:[NSString stringWithFormat:@"SELECT collectionID, collectionName, collectionID IN (SELECT DISTINCT parentCollectionID FROM collections WHERE %@) AS hasChildren FROM collections WHERE %@ AND %@",libraryCondition,libraryCondition,collectionCondition]];
	
    
	
        returnArray = [[NSMutableArray alloc] init];
        
        while([resultSet next]) {
            
            NSInteger collectionID = [resultSet intForColumnIndex:0];
            NSString *name = [resultSet stringForColumnIndex:1];
            BOOL hasChildren = [resultSet intForColumnIndex:2];
            
            ZPZoteroCollection* thisCollection = [[ZPZoteroCollection alloc] init];
            [thisCollection setLibraryID : currentLibraryID];
            [thisCollection setCollectionID : collectionID];
            [thisCollection setName : name];
            [thisCollection setHasChildren:hasChildren];
            
            [returnArray addObject:thisCollection];
            
        }
	}
    
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
    _currentlyActiveLibraryID = view.libraryID;
     
    // Start by deciding if we need to connect to the server or can use cache. We can rely on cache if this collection is completely cached already
    // Check the possible values from the header file
    
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

- (void) _retrieveAndSetInitialKeysForView:(ZPDetailViewController*)view{

    NSInteger collectionID=view.collectionID;
    NSInteger libraryID =  view.libraryID;
    NSString* searchString = [view.searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString* sortField = view.sortField;
    BOOL sortDescending = view.sortDescending;

    NSString* collectionKey = NULL;

    if(collectionID!=0){
        collectionKey = [self collectionKeyFromCollectionID:view.collectionID];
    }
    
    //Retrieve initial 15 items
    
    ZPServerResponseXMLParser* parserResults = [[ZPServerConnection instance] retrieveItemsFromLibrary:libraryID collection:collectionKey searchString:searchString sortField:sortField sortDescending:sortDescending limit:15 start:0];
    
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
    
    //If the current collection has already been changed, do not queue any more retrievals
    if(!(_currentlyActiveLibraryID==libraryID &&
       ((collectionKey == NULL && _currentlyActiveCollectionKey == NULL) ||  
       [ collectionKey isEqualToString:_currentlyActiveCollectionKey] ))) return;
  
        
    //Retrieve the rest of the items into the array
    ZPItemRetrieveOperation* retrieveOperation = [[ZPItemRetrieveOperation alloc] initWithArray: returnArray library:libraryID collection:collectionKey searchString:searchString sortField:sortField sortDescending:sortDescending queue:_serverRequestQueue];
    
    
    
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
            ZPItemRetrieveOperation* retrieveOperationForCache = [[ZPItemRetrieveOperation alloc] initWithArray: [NSArray array] library:libraryID collection:collectionKey searchString:NULL sortField:NULL sortDescending:NO queue:_serverRequestQueue];
            [retrieveOperationForCache markAsInitialRequestForCollection];
            [_serverRequestQueue addOperation:retrieveOperationForCache];
        }
        // Mark that we have started retrieving things from the server 
        [_collectionCacheStatus setValue:[NSNumber numberWithInt:1] forKey:[NSNumber numberWithInt:collectionID]];
    }
    
    [view setItemKeysShown: returnArray];
    [view notifyDataAvailable];
    
}

-(NSString*) collectionKeyFromCollectionID:(NSInteger)collectionID{
    @synchronized(self){
        //TODO: This could be optimized by loading the results in an array or dictionary instead of retrieving them from the database over and over 
        FMResultSet* resultSet = [_database executeQuery:@"SELECT key FROM collections WHERE collectionID = ? LIMIT 1",[NSNumber numberWithInt: collectionID]];
        [resultSet next];
        return [resultSet stringForColumnIndex:0];
    }
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
    
    @synchronized(self){
    //TODO: Implement modifying already existing items if they are older than the new item
    FMResultSet* resultSet = [_database executeQuery:[NSString stringWithFormat: @"SELECT dateModified, itemID FROM items WHERE key ='%@' LIMIT 1",item.key]];

        if(! [resultSet next]){
            
            //TODO: implement item types
            //TODO: implement dateModified
            
            NSNumber* year;
            if(item.year!=0){
                year=[NSNumber numberWithInt:item.year];
            }
            else{
                year=NULL;
            }

            NSNumber* libraryID;
            if(item.libraryID!=0){
                libraryID=[NSNumber numberWithInt:item.libraryID];
            }
            else{
                libraryID=NULL;
            }

            
            [_database executeUpdate:@"INSERT INTO items (itemTypeID,libraryID,year,authors,title,publishedIn,key) VALUES (0,?,?,?,?,?,?)",libraryID,year,item.creatorSummary,item.title,item.publishedIn,item.key];
            
        }
    }
}

- (ZPZoteroItem*) getItemByKey: (NSString*) key{
  
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery: @"SELECT itemTypeID,libraryID,year,authors,title,publishedIn,key FROM items WHERE key=? LIMIT 1",key];
        
        ZPZoteroItem* item = NULL;
        
        if ([resultSet next]) {
            
            item = [[ZPZoteroItem alloc] init];
            //TODO: Implement item type
            [item setLibraryID:[resultSet intForColumnIndex:1]];
            [item setYear:[resultSet intForColumnIndex:2]];
            [item setCreatorSummary:[resultSet stringForColumnIndex:3]];
            [item setTitle:[resultSet stringForColumnIndex:4]];
            NSString* publishedIn = [resultSet stringForColumnIndex:5];
            [item setPublishedIn:publishedIn];
            [item setKey:[resultSet stringForColumnIndex:6]];
        }
        
        return item;
    }
}


/*
 Returns the creators (i.e. authors) for an item
 
 */

- (NSArray*) getCreatorsForItem: (NSInteger) itemID  {

    /*
    FMResultSet* resultSet = [_database executeQuery:[NSString stringWithFormat: @"SELECT firstName, lastName FROM itemCreators, creators, creatorData WHERE itemCreators.itemID = %i AND itemCreators.creatorID = creators.creatorID AND creators.creatorDataID = creatorData.creatorDataID ORDER BY itemCreators.orderIndex ASC",itemID]];
    
    

	NSMutableArray* returnArray = [[NSMutableArray alloc] init];
    
	while([resultSet next]) {
		
		
		NSString *creatorName = [NSString stringWithFormat:@"%s, %s", [resultSet stringForColumnIndex:](selectstmt, 1), [resultSet stringForColumnIndex:](selectstmt, 0)];
        
        [returnArray addObject:creatorName];
	}
	
	sqlite3_finalize(selectstmt);
	
	return returnArray;
     */
    
    return NULL;
}

/*
 Returns the  fields for an item as a dictionary
 */

- (NSDictionary*) getFieldsForItem: (NSInteger) itemID  {
    /*
    FMResultSet* resultSet = [_database executeQuery:[NSString stringWithFormat: @"SELECT fieldName, value FROM itemData, fields, itemDataValues WHERE itemData.itemID = %i AND itemData.fieldID = fields.fieldID AND itemData.valueID = itemDataValues.valueID",itemID]];
    
	NSMutableDictionary* returnDictionary = [[NSMutableDictionary alloc] init];
    
	while([resultSet next]) {
        
        
		NSString *key = [[NSString alloc] initWithUTF8String:(const char *) [resultSet stringForColumnIndex:](selectstmt, 0)];
        NSString *value = [[NSString alloc] initWithUTF8String:(const char *) [resultSet stringForColumnIndex:](selectstmt, 1)];
        
        [returnDictionary setObject:value forKey:key];
	}
    
	sqlite3_finalize(selectstmt);
    
	return returnDictionary;
     */
    
    return NULL;
}


- (NSArray*) getAttachmentFilePathsForItem: (NSInteger) itemID{

    /*
    FMResultSet* resultSet =[_database executeQuery:[NSString stringWithFormat: @"SELECT key, path FROM itemAttachments ia, items i WHERE ia.sourceItemID=%i AND ia.linkMode=1 AND ia.mimeType='application/pdf' AND i.itemID=ia.itemID;",itemID]];
        
    
    NSMutableArray* returnArray = [[NSMutableArray alloc] init];
    
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];

        
    while([resultSet next]) {
            
        //Remove the storage: from the beginning of the filename
        NSString *attachmentPath = [NSString stringWithFormat:@"%@/storage/%s/%@", documentsDirectory, [resultSet stringForColumnIndex:](selectstmt, 0), [[[NSString alloc] initWithUTF8String:(const char *) [resultSet stringForColumnIndex:](selectstmt, 1)]substringFromIndex: 8]];
        
        NSLog(@"%@",attachmentPath);
        
        [returnArray addObject:attachmentPath];
    }
        
    sqlite3_finalize(selectstmt);
        
    return returnArray;
    */
    
    return NULL;
}    


@end
