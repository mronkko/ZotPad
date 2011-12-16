//
//  ZPDatabase.m
//  ZotPad
//
//  This class contains all database operations.
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPDatabase.h"

//Data objects
#import "ZPZoteroLibrary.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroItem.h"

//DB library
#import "../FMDB/src/FMDatabase.h"
#import "../FMDB/src/FMResultSet.h"


@implementation ZPDatabase

static ZPDatabase* _instance = nil;

-(id)init
{
    self = [super init];
    
    _debugDatabase = FALSE;
    
	NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"zotpad.sqlite"];
    
    
    NSError* error;
    
    _database = [FMDatabase databaseWithPath:dbPath];
    [_database open];
    [_database setTraceExecution:_debugDatabase];
    [_database setLogsErrors:_debugDatabase];
    
    //Read the database structure from file and create the database
    
    NSStringEncoding encoding;
    
    NSString *sqlFile = [NSString stringWithContentsOfFile:[[NSBundle mainBundle]
                                                            pathForResource:@"database"
                                                            ofType:@"sql"] usedEncoding:&encoding error:&error];
    
    NSArray *sqlStatements = [sqlFile componentsSeparatedByString:@";"];
    
    NSEnumerator *e = [sqlStatements objectEnumerator];
    id sqlString;
    while (sqlString = [e nextObject]) {
        [_database executeUpdate:sqlString];
    }
    
    
	return self;
}

/*
 Singleton accessor
 */

+(ZPDatabase*) instance {
    if(_instance == NULL){
        _instance = [[ZPDatabase alloc] init];
    }
    return _instance;
}

-(void) addOrUpdateLibraries:(NSArray*)libraries{
    
    @synchronized(self){
        [_database executeUpdate:@"DELETE FROM groups"];
    
    
        NSEnumerator* e = [libraries objectEnumerator];
    
        ZPZoteroLibrary* library;
    
        while ( library = (ZPZoteroLibrary*) [e nextObject]) {
        
            NSNumber* libraryID = [NSNumber numberWithInt:library.libraryID];
            [_database executeUpdate:@"INSERT INTO groups (groupID, name) VALUES (?, ?)",libraryID,library.name];
        }  
    }
}


-(void) addOrUpdateCollections:(NSArray*)collections forLibrary:(NSInteger)libraryID{

    NSMutableArray* collectionKeys;
    
    @synchronized(self){
        FMResultSet* resultSet=[_database executeQuery:@"SELECT key FROM collections WHERE libraryID = ?",[NSNumber numberWithInt:libraryID]];
        
        collectionKeys =[[NSMutableArray alloc] init];
        
        while([resultSet next]){
            [collectionKeys addObject:[resultSet stringForColumnIndex:0]];
        }
        [resultSet close];
    }
    
    NSEnumerator* e2 = [collections objectEnumerator];
    
    ZPZoteroCollection* collection;
    while( collection =(ZPZoteroCollection*)[e2 nextObject]){
        
        //Insert or update
        NSInteger count= [collectionKeys count];
        [collectionKeys removeObject:collection.collectionKey];
        
        NSNumber* libraryIDobj = NULL;
        if(libraryID == 1) libraryIDobj = [NSNumber numberWithInt:libraryID];
        
        @synchronized(self){
            if(count == [collectionKeys count]){
                
                [_database executeUpdate:@"INSERT INTO collections (collectionName, key, libraryID, parentCollectionKey) VALUES (?,?,?,?)",collection.name,collection.collectionKey,libraryIDobj,collection.parentCollectionKey];
            }
            else{
                [_database executeUpdate:@"UPDATE collections SET collectionName=?, libraryID=?, parentCollectionKey=? WHERE key=?",collection.name,libraryIDobj,collection.parentCollectionKey ,collection.collectionKey];
            }
        }
        
    }
    
    // Delete collections that no longer exist
    
    NSEnumerator* e3 = [collectionKeys objectEnumerator];
    
    NSString* key;
    while( key =(NSString*)[e3 nextObject]){
        @synchronized(self){
            [_database executeUpdate:@"DELETE FROM collections WHERE key=?",key];
        }
    }
    
    // Resolve parent IDs based on parent keys
    // A nested subquery is needed to rename columns because SQLite does not support table aliases in update statement

    // TODO: Refactor so that collectionKeys are used instead of collectionIDs

}


//Extract data from item and write to database

-(void) writeItemCreatorsToDatabase:(ZPZoteroItem*)item;
-(void) writeItemFieldsToDatabase:(ZPZoteroItem*)item;


// Methods for retrieving data from the data layer
- (NSArray*) libraries{
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
        [resultSet close];
        
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
        [resultSet close];
        
    }
	return returnArray;
}

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
        [resultSet close];
        
        
	}
    
	return returnArray;
}

//Add more data to an existing item. By default the getItemByKey do not populate fields or creators to save database operations
- (void) getFieldsForItemKey: (NSString*) key{

}
- (void) getCreatorsForItemKey: (NSString*) key{

}

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
            
            
            [_database executeUpdate:@"INSERT INTO items (itemTypeID,libraryID,year,authors,title,publishedIn,key,fullCitation) VALUES (0,?,?,?,?,?,?,?)",libraryID,year,item.creatorSummary,item.title,item.publishedIn,item.key,item.fullCitation];
            
        }
        [resultSet close];
        
    }
}

- (ZPZoteroItem*) getItemByKey: (NSString*) key{
    
    return [[ZPDatabase instance] getItemByKey:key];
    
    ZPZoteroItem* item = NULL;
    
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery: @"SELECT itemTypeID,libraryID,year,authors,title,publishedIn,key,fullCitation FROM items WHERE key=? LIMIT 1",key];
        
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
            [item setFullCitation:[resultSet stringForColumnIndex:7]];
        }
        [resultSet close];
    }
    return item;
}

-(void) writeItemCreatorsToDatabase:(ZPZoteroItem*)item{
    
    //Creators
    @synchronized(self){
        
        //Drop all creators for this 
        //TODO: This could be optimized so that it would work the same way as fields: only do changes that are required instead of dropping and recreating everything
        [_database executeUpdate:@"DELETE FROM creators WHERE itemKey =?",item.key];
        
        
        NSEnumerator* e = [item.creators objectEnumerator];
        NSInteger order=1;
        NSDictionary* creator;
        
        while(creator= [e nextObject]){
            [_database executeUpdate:[NSString stringWithFormat: @"INSERT INTO creators (itemKey,order,firstName,lastName,shortName,creatorType) VALUES (?,?,?,?,?)",
                                      item.key,order,[creator objectForKey:@"firstName"],[creator objectForKey:@"lastName"],
                                      [creator objectForKey:@"shortName"],[creator objectForKey:@"creatorType"]]];
            order++;
        }
    }
}
-(void) writeItemFieldsToDatabase:(ZPZoteroItem*)item{
    
    //Fields      
    NSMutableDictionary* oldFields=[[NSMutableDictionary alloc] init];
    
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery:@"SELECT fieldName, fieldValue FROM fields WHERE itemKey = ? ",item.key];
        
        while([resultSet next]){
            [oldFields setObject:[resultSet stringForColumnIndex:0] forKey:[resultSet stringForColumnIndex:1]];
        }
        [resultSet close];
    }
    
    NSEnumerator* e = [item.fields keyEnumerator]; 
    
    NSString* key;
    
    while(key=[e nextObject]){
        NSString* oldValue = [oldFields objectForKey:key];
        if(oldValue == NULL){
            @synchronized(self){
                [_database executeUpdate:@"INSERT INTO fields (fieldName, fieldValue, itemKey) VALUES (?,?,?)",key,[item.fields objectForKey:key],item.key];
            }
        }
        else if (! [oldValue isEqualToString:[item.fields objectForKey:key]]){
            @synchronized(self){
                [_database executeUpdate:@"UPDATE fields SET fieldValue = ? WHERE fieldName=? AND itemKey = ? ",[item.fields objectForKey:key],key,item.key];
            }
        }
        [oldFields removeObjectForKey:key];
    }
    
    e = [oldFields keyEnumerator]; 
    
    while(key=[e nextObject]){
        @synchronized(self){
            [_database executeUpdate:@"DELETE FROM fields WHERE fieldName = ? AND  itemKey = ?",key,item.key];
        }
    }
    
}


- (void) addCreatorsToItem: (ZPZoteroItem*) item {
    
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery: @"SELECT firstName, lastName, shortName,creatorType, fieldMode FROM creators WHERE itemKey = ? ORDER BY order",item.key];
        
        NSMutableArray* creators = [[NSMutableArray alloc] init];
        
        while([resultSet next]) {
            NSMutableDictionary* creator = [[NSMutableDictionary alloc] init];
            
            [creator setObject:[resultSet stringForColumnIndex:0] forKey:@"firstName"];
            [creator setObject:[resultSet stringForColumnIndex:1] forKey:@"lastName"];
            [creator setObject:[resultSet stringForColumnIndex:2] forKey:@"shortName"];
            [creator setObject:[resultSet stringForColumnIndex:3] forKey:@"creatorType"];
            
            //TODO: Would this be needed at all?
            //[creator setObject:[NSNumber numberWithInt:[resultSet intForColumnIndex:4]] forKey:@"fieldMode"];
            
            [creators addObject:creator];
        }
        
        [resultSet close];
        if([creators count]>0) item.creators = creators;
        else item.creators = NULL;
    }
}



- (void) addFieldsToItem: (ZPZoteroItem*) item  {
    
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery: @"SELECT fieldName, fieldValue FROM fields WHERE itemKey = ? ",item.key];
        
        NSMutableDictionary* fields = [[NSMutableDictionary alloc] init];
        while([resultSet next]) {
            
            [fields setObject:[resultSet stringForColumnIndex:0] forKey:[resultSet stringForColumnIndex:1]];
        }
        
        [resultSet close];
        
        if([fields count]>0) item.fields = fields;
        else item.fields = NULL;
    }
}


/*

- (NSArray*) getAttachmentFilePathsForItem: (NSInteger) itemID{
    
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
    
    return NULL;
}    
 */


@end
