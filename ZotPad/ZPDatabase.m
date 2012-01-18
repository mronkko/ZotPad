//
//  ZPDatabase.m
//  ZotPad
//
//  This class contains all database operations.
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

//
// Try to do only one query per function. This makes profiling the application with Instruments much easier.
//

#include <sys/xattr.h>


#import "ZPDatabase.h"

//Data objects
#import "ZPZoteroLibrary.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroNote.h"
#import "ZPZoteroAttachment.h"

//DB library
#import "../FMDB/src/FMDatabase.h"
#import "../FMDB/src/FMResultSet.h"

#import "ZPPreferences.h"

#import "ZPLogger.h"

@interface  ZPDatabase ()
- (NSDictionary*) _fieldsForItem:(ZPZoteroItem*)item;
- (NSArray*) _creatorsForItem:(ZPZoteroItem*)item;

@end

@implementation ZPDatabase

static ZPDatabase* _instance = nil;

-(id)init
{
    self = [super init];
    _instance = self;
    
	NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"zotpad.sqlite"];
   
    if(! [[NSFileManager defaultManager] fileExistsAtPath:dbPath]) [self resetDatabase];
    else{
        _database = [FMDatabase databaseWithPath:dbPath];
        [_database open];
    }

    [_database setTraceExecution:FALSE];
    [_database setLogsErrors:TRUE];

	return self;
}

/*
 Singleton accessor. If ZotPad is set to not use cache, prevent accessing this boject by returning NULL
 */

+(ZPDatabase*) instance {
    if([[ZPPreferences instance] useCache]){
        @synchronized(self){
            if(_instance == NULL){
                _instance = [[ZPDatabase alloc] init];
            }
            return _instance;
        }
    }
    else return NULL;
}

-(void) resetDatabase{
    @synchronized(self){
        NSLog(@"Reseting database");
        
        NSError* error;
        
        NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"zotpad.sqlite"];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:dbPath]){
            [[NSFileManager defaultManager] removeItemAtPath: dbPath error:&error];   
        }
        
        _database = [FMDatabase databaseWithPath:dbPath];
        
        [_database open];  
        //Prevent backing up of DB
        const char* filePath = [dbPath fileSystemRepresentation];
        const char* attrName = "com.apple.MobileBackup";
        u_int8_t attrValue = 1;
        setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
        
        //Changing these two will affect how much info is printed in log
        [_database setTraceExecution:FALSE];
        [_database setLogsErrors:TRUE];
        
        //Read the database structure from file and create the database
        
        //TODO: Consider running this in a background thread. The SQL file would probably need to split into two parts because some tables are needed early on in the library and collection retrieval process
        
        NSStringEncoding encoding;
        
        NSString *sqlFile = [NSString stringWithContentsOfFile:[[NSBundle mainBundle]
                                                                pathForResource:@"database"
                                                                ofType:@"sql"] usedEncoding:&encoding error:&error];
        
        NSArray *sqlStatements = [sqlFile componentsSeparatedByString:@";"];
        
        NSEnumerator *e = [sqlStatements objectEnumerator];
        id sqlString;
        
        while (sqlString = [e nextObject]) {
            if(! [[sqlString stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]) [_database executeUpdate:sqlString];
        }
        
        
        NSLog(@"Database reset completed");

    }

}

-(void) addOrUpdateLibraries:(NSArray*)libraries{
    
    @synchronized(self){
        //Delete everything but leave my library
        FMResultSet* resultSet = [_database executeQuery:@"SELECT groupID,lastCompletedCacheTimestamp FROM groups"];
        
        NSMutableDictionary* timestamps = [NSMutableDictionary dictionary];
        while([resultSet next]){
            if([resultSet stringForColumnIndex:1] != NULL) [timestamps setObject:[resultSet stringForColumnIndex:1] forKey:[NSNumber numberWithInt:[resultSet intForColumnIndex:0]]];
        }
        [resultSet close];
        
        [_database executeUpdate:@"DELETE FROM groups WHERE groupID != 1"];

    
        NSEnumerator* e = [libraries objectEnumerator];
    
        ZPZoteroLibrary* library;
    
        while ( library = (ZPZoteroLibrary*) [e nextObject]) {
            
            NSNumber* libraryID = library.libraryID;
            [_database executeUpdate:@"INSERT INTO groups (groupID, title,lastCompletedCacheTimestamp) VALUES (?, ?, ?)",libraryID,library.title,[timestamps objectForKey:libraryID]];
        }
    }
}


-(void) addOrUpdateCollections:(NSArray*)collections forLibrary:(ZPZoteroLibrary*)library{

    NSMutableArray* collectionKeys;
    
    @synchronized(self){
        FMResultSet* resultSet=[_database executeQuery:@"SELECT key FROM collections WHERE libraryID = ?",library.libraryID];
        
        collectionKeys =[[NSMutableArray alloc] init];
        
        while([resultSet next]){
            library.hasChildren = YES;
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
                
        @synchronized(self){
            if(count == [collectionKeys count]){
                
                [_database executeUpdate:@"INSERT INTO collections (title, key, libraryID, parentCollectionKey,lastCompletedCacheTimestamp) VALUES (?,?,?,?,?)",collection.title,collection.collectionKey,library.libraryID,collection.parentCollectionKey,collection.lastCompletedCacheTimestamp];
            }
            else{
                [_database executeUpdate:@"UPDATE collections SET title=?, libraryID=?, parentCollectionKey=?,lastCompletedCacheTimestamp=? WHERE key=?",collection.title,library.libraryID,collection.parentCollectionKey ,collection.lastCompletedCacheTimestamp,collection.collectionKey];
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
}

-(BOOL) doesItemKey:(NSString*)itemKey belongToCollection:(NSString*) collectionKey{
    @synchronized(self){
        
        FMResultSet* resultSet = [_database executeQuery:@"SELECT itemKey FROM collectionItems WHERE itemKey = ? AND collectionKey = ?",itemKey,collectionKey];
		
        BOOL ret = [resultSet next];
            
        [resultSet close];
        
        return ret;
        
    }

}


// These remove items from the collection
- (void) removeItemKeysNotInArray:(NSArray*)itemKeys fromCollection:(NSString*)collectionKey{

    if([itemKeys count] == 0) return;

    @synchronized(self){
        //This might generate a too long query
        [_database executeUpdate:[NSString stringWithFormat:@"DELETE FROM collectionItems WHERE collectionKey = ? AND itemKey NOT IN ('%@')",
                                                           [itemKeys componentsJoinedByString:@"', '"]],collectionKey];
    }

}

/*
 
Deletes items, notes, and attachments
 
 */

- (void) deleteItemKeysNotInArray:(NSArray*)itemKeys fromLibrary:(NSNumber*)libraryID{
    
    BOOL debugThisFunction = FALSE;
    if([itemKeys count] == 0) return;
    
    @synchronized(self){
        //This might generate a too long query, so needs to be tested with very large libraries
        if(debugThisFunction){
            FMResultSet* rs = [_database executeQuery:@"SELECT COUNT(key) FROM items WHERE libraryID=?",libraryID];
            [rs next];
            NSLog(@"Items prior to delete %i",[rs intForColumnIndex:0]);
            [rs close];
            
        }
        [_database executeUpdate:[NSString stringWithFormat:@"DELETE FROM items WHERE libraryID = ? AND key NOT IN ('%@')",
                                  [itemKeys componentsJoinedByString:@"', '"]],libraryID];
        if(debugThisFunction){
            FMResultSet* rs = [_database executeQuery:@"SELECT COUNT(key) FROM items WHERE libraryID=?",libraryID];
            [rs next];
            NSLog(@"Items after delete %i",[rs intForColumnIndex:0]);
            [rs close];
            
        }

        if(debugThisFunction){
            FMResultSet* rs = [_database executeQuery:@"SELECT COUNT(key) FROM attachments WHERE parentItemKey IN (SELECT key FROM items WHERE libraryID = ?)",libraryID];
            [rs next];
            NSLog(@"Attachments prior to delete %i",[rs intForColumnIndex:0]);
            [rs close];
            
        }

        [_database executeUpdate:[NSString stringWithFormat:@"DELETE FROM attachments WHERE key NOT IN ('%@') AND parentItemKey IN (SELECT key FROM items WHERE libraryID = ?)",
                                  [itemKeys componentsJoinedByString:@"', '"]],libraryID];

        if(debugThisFunction){
            FMResultSet* rs = [_database executeQuery:@"SELECT COUNT(key) FROM attachments WHERE parentItemKey IN (SELECT key FROM items WHERE libraryID = ?)",libraryID];
            [rs next];
            NSLog(@"Attachments after delete %i",[rs intForColumnIndex:0]);
            [rs close];
            
        }

        
        if(debugThisFunction){
            FMResultSet* rs = [_database executeQuery:@"SELECT COUNT(key) FROM notes WHERE parentItemKey IN (SELECT key FROM items WHERE libraryID = ?)",libraryID];
            [rs next];
            NSLog(@"Notes prior to delete %i",[rs intForColumnIndex:0]);
            [rs close];
            
        }

        [_database executeUpdate:[NSString stringWithFormat:@"DELETE FROM notes WHERE key NOT IN ('%@') AND parentItemKey in (SELECT key FROM items WHERE libraryID = ?)",
                                  [itemKeys componentsJoinedByString:@"', '"]],libraryID];

        if(debugThisFunction){
            FMResultSet* rs = [_database executeQuery:@"SELECT COUNT(key) FROM notes WHERE parentItemKey IN (SELECT key FROM items WHERE libraryID = ?)",libraryID];
            [rs next];
            NSLog(@"Notes after delete %i",[rs intForColumnIndex:0]);
            [rs close];
            
        }

    }
}

- (void) setUpdatedTimestampForCollection:(NSString*)collectionKey toValue:(NSString*)updatedTimestamp{
    @synchronized(self){
        [_database executeUpdate:@"UPDATE collections SET lastCompletedCacheTimestamp = ? WHERE key = ?",updatedTimestamp,collectionKey];
    }
}
- (void) setUpdatedTimestampForLibrary:(NSNumber*)libraryID toValue:(NSString*)updatedTimestamp{
    @synchronized(self){
        [_database executeUpdate:@"UPDATE groups SET lastCompletedCacheTimestamp = ? WHERE groupID = ?",updatedTimestamp,libraryID];
    }
}


// Methods for retrieving data from the data layer

//TODO: Optimize so that the results from the query can be used when initializing library objects

- (NSArray*) libraries{
    NSMutableArray *returnArray = [[NSMutableArray alloc] init];
    NSMutableArray* keyArray = [[NSMutableArray alloc] init];
    
    //Group libraries
    @synchronized(self){
        
        FMResultSet* resultSet = [_database executeQuery:@"SELECT groupID FROM groups"];

        
        while([resultSet next]) {
            [keyArray addObject:[NSNumber numberWithInt:[resultSet intForColumnIndex:0]]];
        }
        [resultSet close];
    }
    for(NSNumber* key in keyArray){
        [returnArray addObject:[ZPZoteroLibrary ZPZoteroLibraryWithID:key]];
    }

	return returnArray;
}

- (void) addFieldsToLibrary:(ZPZoteroLibrary*) library{
    //Group libraries
    @synchronized(self){
        
        FMResultSet* resultSet = [_database executeQuery:@"SELECT title,  groupID IN (SELECT DISTINCT libraryID from collections) AS hasChildren, lastCompletedCacheTimestamp FROM groups WHERE groupID = ?",library.libraryID];
		
        
        if([resultSet next]){
        
            NSString* name = [resultSet stringForColumnIndex:0];
            BOOL hasChildren = [resultSet boolForColumnIndex:1];
        
            [library setTitle: name];
            [library setHasChildren:hasChildren];
            [library setLastCompletedCacheTimestamp:[resultSet stringForColumnIndex:2]];
        }
        [resultSet close];
        
    }
}


- (NSArray*) collectionsForLibrary : (NSNumber*)libraryID withParentCollection:(NSString*)collectionKey {
	
    
    
    NSMutableArray* returnArray = [[NSMutableArray alloc] init];
    NSMutableArray* keyArray = [[NSMutableArray alloc] init];
    
	@synchronized(self){
        
        FMResultSet* resultSet;
        if(collectionKey == NULL)
            resultSet= [_database executeQuery:@"SELECT key FROM collections WHERE libraryID=? AND parentCollectionKey IS NULL",libraryID,libraryID];
        
        else
            resultSet= [_database executeQuery:@"SELECT key FROM collections WHERE libraryID=? AND parentCollectionKey = ?",libraryID,libraryID,collectionKey];
        
        
        
        returnArray = [[NSMutableArray alloc] init];
        
        while([resultSet next]) {
            [keyArray addObject:[resultSet stringForColumnIndex:0]];
                
        }
        [resultSet close];
        
	}

    for(NSString* key in keyArray){
        [returnArray addObject:[ZPZoteroCollection ZPZoteroCollectionWithKey:key]];
    }
	return returnArray;
}


- (NSArray*) allCollectionsForLibrary:(NSNumber*)libraryID{	

    NSMutableArray* returnArray = [[NSMutableArray alloc] init];;
    NSMutableArray* keyArray = [[NSMutableArray alloc] init];
    
    //TODO: Refactor: Make a method that takes a row from resulset and then creates an object from it.
    // resultDict method in FMResultSet is probably useful for this
    
	@synchronized(self){
        FMResultSet* resultSet = [_database executeQuery:@"SELECT key FROM collections WHERE libraryID=?",libraryID];

        while([resultSet next]) {
            [keyArray addObject:[resultSet stringForColumnIndex:0]];
        }
        [resultSet close];
    }

    for(NSString* key in keyArray){
        [returnArray addObject:[ZPZoteroCollection ZPZoteroCollectionWithKey:key]];
    }
    
	return returnArray;
}

- (void) addFieldsToCollection:(ZPZoteroCollection*) collection{
    
    
	@synchronized(self){
        FMResultSet* resultSet = [_database executeQuery:@"SELECT libraryID, title, key IN (SELECT DISTINCT parentCollectionKey FROM collections) AS hasChildren, lastCompletedCacheTimestamp, parentCollectionKey FROM collections WHERE key=?",collection.collectionKey];
        
        
        if([resultSet next]){
        
            [collection setLibraryID : [NSNumber numberWithInt:[resultSet intForColumnIndex:0]]];
            [collection setTitle : [resultSet stringForColumnIndex:1]];
            [collection setHasChildren:(BOOL) [resultSet intForColumnIndex:2]];
            [collection setLastCompletedCacheTimestamp:[resultSet stringForColumnIndex:3]];
            [collection setParentCollectionKey:[resultSet stringForColumnIndex:3]];
        }
        
        [resultSet close];
    
    }
}



-(NSArray*) addItemsToDatabase:(NSArray*)items {
    
    
    if([items count] == 0) return items;

    ZPZoteroItem* item;

    NSMutableArray* itemKeys = [NSMutableArray array];
    for(item in items){
        [itemKeys addObject:item.key];
    }
    
    NSMutableDictionary* timestamps = [NSMutableDictionary dictionary];

    //Retrieve timestamps
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery:[NSString stringWithFormat:@"SELECT key, lastTimestamp FROM items WHERE key IN ('%@')",[itemKeys componentsJoinedByString:@"', '"]]];
    
        while([resultSet next]){
            [timestamps setObject:[resultSet stringForColumnIndex:1] forKey:[resultSet stringForColumnIndex:0]];
        }
        [resultSet close];
    }

    NSMutableArray* returnArray=[NSMutableArray array]; 

    NSMutableArray* itemsRemaining = [NSMutableArray arrayWithArray:items];
    
    while([itemsRemaining count]>0){
        
        NSMutableArray* itemBatch = [NSMutableArray array];
        
        //The maximum rows in union select is 500. (http://www.sqlite.org/limits.html)
        
        NSInteger counter =0;
        ZPZoteroItem* item = [itemsRemaining lastObject];
        while(counter  < 500 && item != NULL){
            [itemBatch addObject:item];
            [itemsRemaining removeLastObject];
            counter++;
            item = [itemsRemaining lastObject];
        }
        
        
        NSString* insertSQL;
        NSMutableArray* insertArguments = [NSMutableArray array];
        
        for (item in itemBatch){
            
            //Check the timestamp
            NSString* timestamp = [timestamps objectForKey:item.key];
            
            
            NSObject* year;
            if(item.year!=0){
                year=[NSNumber numberWithInt:item.year];
            }
            else{
                year = [NSNull null];
            }
            
            if(timestamp == NULL){
                /*
                 
                 IMPORTANT: the order of the fields in this SQL query must match exactly those in the database.
                 
                 */
                if(insertSQL == NULL){
                    insertSQL = @"INSERT INTO items (key, itemType, libraryID, year, creator, title, publishedIn,  fullCitation, lastTimestamp) SELECT ? AS key, ? AS itemType, ? AS libraryID, ? AS year, ? AS creator, ? AS title, ? AS publishedIn,  ? AS fullCitation, ? AS lastTimestamp";
                }
                else{
                    insertSQL = [insertSQL stringByAppendingString:@" UNION SELECT ?,?,?,?,?,?,?,?,?"];
                }
                
                NSString* publishedIn = item.publishedIn;
                if(publishedIn == NULL) publishedIn =@"";
                
                NSString* creatorSummary = item.creatorSummary;
                if(creatorSummary == NULL) creatorSummary =@"";
                
                
                [insertArguments addObjectsFromArray:[NSArray arrayWithObjects:item.key,item.itemType,item.libraryID,year,creatorSummary,item.title,publishedIn,item.fullCitation,item.lastTimestamp,nil]];
                
                [returnArray addObject:item];
            }
            
            else if(! [item.lastTimestamp isEqualToString: timestamp]){
                @synchronized(self){
                    [_database executeUpdate:@"UPDATE items SET itemType = ?, libraryID = ?, year = ?,creator =? ,title = ?,publishedIn = ?,fullCitation =?,lastTimestamp = ? WHERE key = ?",item.itemType,item.libraryID,year,item.creatorSummary,item.title,item.publishedIn,item.fullCitation,item.lastTimestamp,item.key];
                }
                [returnArray addObject:item];
            }
            
        }
        
        if(insertSQL != NULL){
            @synchronized(self){
                [_database executeUpdate:insertSQL withArgumentsInArray:insertArguments]; 
            }
        }
    }
    return returnArray;
        
}

-(void) addNotesToDatabase:(NSArray*)notes{
    
    if([notes count] == 0) return;

    
    ZPZoteroNote* note;
    
    NSMutableArray* itemKeys = [NSMutableArray array];

    for(note in notes){
        [itemKeys addObject:note.key];
    }
    
    NSMutableDictionary* timestamps = [NSMutableDictionary dictionary];
    
    //Retrieve timestamps
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery:[NSString stringWithFormat:@"SELECT key, lastTimestamp FROM notes WHERE key IN ('%@')",[itemKeys componentsJoinedByString:@"', '"]]];
        
        while([resultSet next]){
            [timestamps setObject:[resultSet stringForColumnIndex:1] forKey:[resultSet stringForColumnIndex:0]];
        }
        
        [resultSet close];
    }
    
    
    NSString* insertSQL;
    NSMutableArray* insertArguments = [NSMutableArray array];
    
    for(note in notes){
        
        //Check the timestamp
        NSString* timestamp = [timestamps objectForKey:note.key];
        
        if(timestamp == NULL){
            
            if(insertSQL == NULL){
                insertSQL = @"INSERT INTO notes (key, parentItemKey, lastTimestamp) SELECT ? AS key, ? AS parentItemKey, ? AS lastTimestamp";
            }
            else{
                insertSQL = [insertSQL stringByAppendingString:@" UNION SELECT ?,?,?"];
            }
            
            [insertArguments addObjectsFromArray:[NSArray arrayWithObjects:note.key,note.parentItemKey,note.lastTimestamp,nil]];
        }
        else if(! [note.lastTimestamp isEqualToString: timestamp]){
            @synchronized(self){
                [_database executeUpdate:@"UPDATE notes SET parentItemKey = ?,lastTimestamp = ? WHERE key = ?",note.parentItemKey,note.lastTimestamp,note.key];
            }
        }
    }
    
    if(insertSQL != NULL){
        @synchronized(self){
            [_database executeUpdate:insertSQL withArgumentsInArray:insertArguments]; 
        }
    }
}

-(void) addAttachmentsToDatabase:(NSArray*)attachments{

    if([attachments count] == 0) return;

    ZPZoteroAttachment* attachment;
    
    NSMutableArray* itemKeys = [NSMutableArray array];
    for(attachment in attachments){
        [itemKeys addObject:attachment.key];
    }
    
    NSMutableDictionary* timestamps = [NSMutableDictionary dictionary];
    
    //Retrieve timestamps
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery:[NSString stringWithFormat:@"SELECT key, lastTimestamp FROM attachments WHERE key IN ('%@')",[itemKeys componentsJoinedByString:@"', '"]]];
        
        while([resultSet next]){
            [timestamps setObject:[resultSet stringForColumnIndex:1] forKey:[resultSet stringForColumnIndex:0]];
        }
        
        [resultSet close];
    }
    
    
    NSString* insertSQL;
    NSMutableArray* insertArguments = [NSMutableArray array];
    
    for(attachment in attachments){
        
        //Check the timestamp
        NSString* timestamp = [timestamps objectForKey:attachment.key];
        
        if(timestamp == NULL){
            
            // We have at least two different types of attachments. Real files and links. The links are currently not stored (URL is null) but their keys are needed for synchronization.
            if(insertSQL == NULL){
                if(attachment.attachmentURL!=NULL){
                    insertSQL = @"INSERT INTO attachments (key, parentItemKey, lastTimestamp, attachmentURL, attachmentType, attachmentTitle, attachmentLength, lastViewed) SELECT ? AS key, ? AS parentItemKey, ? AS lastTimestamp, ? AS attachmentURL, ? AS attachmentType, ? AS attachmentTitle, ? AS attachmentLength, NULL AS lastViewed";
                }
                else{
                    insertSQL = @"INSERT INTO attachments (key, parentItemKey, lastTimestamp, attachmentURL, attachmentType, attachmentTitle, attachmentLength, lastViewed) SELECT ? AS key, ? AS parentItemKey, ? AS lastTimestamp, NULL AS attachmentURL, NULL AS attachmentType, NULL AS attachmentTitle, NULL AS attachmentLength, NULL AS lastViewed";
                }
            }
            else if(attachment.attachmentURL!=NULL){
                insertSQL = [insertSQL stringByAppendingString:@" UNION SELECT ?,?,?,?,?,?,?,NULL"];
            }
            else{
                insertSQL = [insertSQL stringByAppendingString:@" UNION SELECT ?,?,?,NULL,NULL,NULL,NULL,NULL"];

            }
            [insertArguments addObjectsFromArray:[NSArray arrayWithObjects:attachment.key,attachment.parentItemKey,attachment.lastTimestamp,attachment.attachmentURL,attachment.attachmentType,attachment.attachmentTitle,[NSNumber numberWithInt: attachment.attachmentLength],nil]];
        }
        else if(! [attachment.lastTimestamp isEqualToString: timestamp]){
            @synchronized(self){
                [_database executeUpdate:@"UPDATE attachments SET parentItemKey = ?,lastTimestamp = ?,attachmentURL = ?,attachmentType = ?,attachmentTitle = ?,attachmentLength = ? WHERE key = ?",attachment.parentItemKey,attachment.lastTimestamp,attachment.attachmentURL,attachment.attachmentType,attachment.attachmentTitle,[NSNumber numberWithInt: attachment.attachmentLength],attachment.key];
            }
        }
    }
    
    if(insertSQL != NULL){
        @synchronized(self){
            [_database executeUpdate:insertSQL withArgumentsInArray:insertArguments]; 
        }
    }
}


// Records a new collection membership

-(void) addItems:(NSArray*)items toCollection:(NSString*)collectionKey{
    if([items count] == 0) return;
    
    ZPZoteroItem* item;
    NSMutableArray* itemKeys = [NSMutableArray array];
    for(item in items){
        [itemKeys addObject:item.key];
    }
    [self addItems:itemKeys toCollection:collectionKey];
}


-(void) addItemKeys:(NSArray*)keys toCollection:(NSString*)collectionKey{

    if([keys count]==0) return;
    
    NSMutableArray* itemKeys= [NSMutableArray arrayWithArray:keys];
    
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery:[NSString stringWithFormat:@"SELECT itemKey FROM collectionItems WHERE itemKey NOT IN ('%@') AND  collectionKey = ?",[itemKeys componentsJoinedByString:@"', '"]],collectionKey];
        itemKeys = [NSMutableArray array];
        while([resultSet next]){
            [itemKeys addObject:[resultSet stringForColumnIndex:0]];
        }
        [resultSet close];
    }
    
    NSString* insertSQL;
    NSMutableArray* insertArguments = [NSMutableArray array];
    NSString* itemKey;
    
    for(itemKey in itemKeys){
        if(insertSQL==NULL){
            insertSQL = @"INSERT INTO collectionItems SELECT ? AS collectionKey, ? AS itemKey";
        }
        else{
            insertSQL = [insertSQL stringByAppendingString:@" UNION SELECT ?, ?"];
        }
    
        [insertArguments addObject:collectionKey];
        [insertArguments addObject:itemKey];
    }
    
   if(insertSQL != NULL){
        @synchronized(self){
            [_database executeUpdate:insertSQL withArgumentsInArray:insertArguments]; 
        }
   }

}




- (void) addBasicsToItem:(ZPZoteroItem *)item{
    
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery: @"SELECT itemType,libraryID,year,creator,title,publishedIn,key,fullCitation,lastTimestamp FROM items WHERE key=? LIMIT 1",item.key];
        
        if ([resultSet next]) {
            
            [item setItemType:[resultSet stringForColumnIndex:0]];
            [item setLibraryID:[NSNumber numberWithInt:[resultSet intForColumnIndex:1]]];
            [item setYear:[resultSet intForColumnIndex:2]];
            [item setCreatorSummary:[resultSet stringForColumnIndex:3]];
            [item setTitle:[resultSet stringForColumnIndex:4]];
            NSString* publishedIn = [resultSet stringForColumnIndex:5];
            [item setPublishedIn:publishedIn];
            [item setFullCitation:[resultSet stringForColumnIndex:7]];
            [item setLastTimestamp:[resultSet stringForColumnIndex:8]];

        }
        [resultSet close];
    }
}


/*
 
 Writes or updates the creators for this field in the database
 
 See this for union select
 http://stackoverflow.com/questions/1609637/is-it-possible-to-insert-multiple-rows-at-a-time-in-an-sqlite-database
 
 
 */

-(void) writeItemsCreatorsToDatabase:(NSArray*)items{
    
    if([items count] == 0) return;

    ZPZoteroItem* item;
    NSString* insertSQL;
    NSMutableArray* insertArguments = [NSMutableArray array];

    for(item in items){
        
        NSArray* oldCreators = [self _creatorsForItem:item];
        
       
        NSEnumerator* e = [oldCreators objectEnumerator];
        NSInteger order=1;
        NSDictionary* newCreator;
        NSDictionary* oldCreator;

        for (newCreator in item.creators){
            oldCreator = [e nextObject];
            if(oldCreator == NULL){
                //Insert
                if(insertSQL == NULL){
                    insertSQL = @"INSERT INTO creators (itemKey, \"order\", firstName, lastName, shortName, creatorType)  SELECT ? AS itemKey, ? AS \"order\", ? AS firstName, ? AS lastName, ? AS shortName, ? AS creatorType";
                }
                else{
                    insertSQL = [insertSQL stringByAppendingString:@" UNION SELECT ?,?,?,?,?,?"];
                }

                NSObject* firstName = [newCreator objectForKey:@"firstName"];
                if(firstName == NULL) firstName = [NSNull null];
                NSObject* lastName = [newCreator objectForKey:@"lastName"];
                if(lastName == NULL) lastName = [NSNull null];
                NSObject* shortName = [newCreator objectForKey:@"shortName"];
                if(shortName == NULL) shortName = [NSNull null];
                
                [insertArguments addObjectsFromArray:[NSArray arrayWithObjects:
                                                      item.key,[NSNumber numberWithInt:order],firstName,lastName,shortName,[newCreator objectForKey:@"creatorType"], nil]];
            }
            else if(![oldCreator isEqualToDictionary:newCreator]){
                //Update
                @synchronized(self){
                    [_database executeUpdate:@"UPDATE creators SET firstName = ? , lastName = ? ,shortName = ?,creatorType = ?) WHERE itemKey = ? \"order\" = ?",
                     [newCreator objectForKey:@"firstName"],[newCreator objectForKey:@"lastName"],
                     [newCreator objectForKey:@"shortName"],[newCreator objectForKey:@"creatorType"],item.key,[NSNumber numberWithInt:order]];
                }
            }
            order++;
        }
        //If there are more creators in the DB than there are in the item, delete these
        
        //TODO: Consider optimizing this by running just one delete query for the entire item set.
        
        if([e nextObject]){
            @synchronized(self){
                [_database executeUpdate:@"DELETE FROM creators WHERE itemKey =? AND \"order\" >= ?",item.key,order];
            }
        }

    }
    if(insertSQL != NULL){
        @synchronized(self){
            [_database executeUpdate:insertSQL withArgumentsInArray:insertArguments]; 
        }
    }
    
}

/*
 
 The function writes only fields that have values to the DB. 

 See this for union select
 http://stackoverflow.com/questions/1609637/is-it-possible-to-insert-multiple-rows-at-a-time-in-an-sqlite-database

 
 */


-(void) writeItemsFieldsToDatabase:(NSArray*)items{

    if([items count] == 0) return;

    //This can easily result in too large queries, so we will split them up into batches

    NSMutableArray* itemsRemaining = [NSMutableArray arrayWithArray:items];
    
    while([itemsRemaining count]>0){

        NSMutableArray* itemBatch = [NSMutableArray array];

        //The maximum rows in union select is 500. (http://www.sqlite.org/limits.html)
        
        NSInteger counter =0;
        ZPZoteroItem* item = [itemsRemaining lastObject];
        while(item != NULL && counter + [item.fields count] < 500){
            [itemBatch addObject:item];
            [itemsRemaining removeLastObject];
            counter = counter + [item.fields count];
            item = [itemsRemaining lastObject];
            
        }
        
        NSString* insertSQL=NULL;
        NSMutableArray* insertArguments = [NSMutableArray array];
        
        for (item in itemBatch){
            //Fields      
            NSMutableDictionary* oldFields = [NSMutableDictionary dictionaryWithDictionary:[self _fieldsForItem:item]];
            NSEnumerator* e = [item.fields keyEnumerator]; 
            
            NSString* key;
            
            while(key=[e nextObject]){
                NSString* oldValue = [oldFields objectForKey:key];
                NSString* newValue = [item.fields objectForKey:key];
                
                if(! [newValue isEqualToString:@""]){
                    if(oldValue == NULL ){
                        if(insertSQL == NULL){
                            insertSQL = @"INSERT INTO fields (fieldName, fieldValue, itemKey) SELECT ? AS fieldName, ? AS fieldValue, ? AS itemKey";
                        }
                        else{
                            insertSQL = [insertSQL stringByAppendingString:@" UNION SELECT ?, ?, ? "];
                        }
                        [insertArguments addObject:key];
                        [insertArguments addObject:newValue];
                        [insertArguments addObject:item.key];
                        
                    }
                    else if (! [oldValue isEqualToString:newValue]){
                        @synchronized(self){
                            [_database executeUpdate:@"UPDATE fields SET fieldValue = ? WHERE fieldName=? AND itemKey = ? ",newValue,key,item.key];
                        }
                    }
                    //Remove the field from old fields because it has been written to DB. We will later delete all fields that have not been written to DB.
                    [oldFields removeObjectForKey:key];
                }
            }
            
            e = [oldFields keyEnumerator]; 
            if (key=[e nextObject]) {
                NSMutableArray* deleteArguments = [NSMutableArray arrayWithObject:key];
                NSString* deleteSql = @"DELETE FROM fields WHERE fieldName IN (?";
                [deleteArguments addObject:key];
                while(key=[e nextObject]){
                    [deleteArguments addObject:key];
                    deleteSql = [deleteSql stringByAppendingString:@", ?"];
                }
                deleteSql = [deleteSql stringByAppendingString:@") AND  itemKey = ?"];
                [deleteArguments addObject:item.key];
                
                @synchronized(self){
                    [_database executeUpdate:deleteSql withArgumentsInArray:deleteArguments];
                }
            }    
        }
        if(insertSQL != NULL){
            @synchronized(self){
                [_database executeUpdate:insertSQL withArgumentsInArray:insertArguments]; 
            }
        }
    }
}

- (NSDictionary*) _fieldsForItem:(ZPZoteroItem*)item{
    NSMutableDictionary* fields=[[NSMutableDictionary alloc] init];
    
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery:@"SELECT fieldName, fieldValue FROM fields WHERE itemKey = ? ",item.key];
        
        while([resultSet next]){
            [fields setObject:[resultSet stringForColumnIndex:0] forKey:[resultSet stringForColumnIndex:1]];
        }
        [resultSet close];
    }
    return fields;
}

- (NSArray*) _creatorsForItem:(ZPZoteroItem*)item{
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery: @"SELECT firstName, lastName, shortName,creatorType FROM creators WHERE itemKey = ? ORDER BY \"order\"",item.key];
        
        NSMutableArray* creators = [[NSMutableArray alloc] init];
        
        while([resultSet next]) {
            NSMutableDictionary* creator = [[NSMutableDictionary alloc] init];
            
            if([resultSet stringForColumnIndex:0]!=NULL) [creator setObject:[resultSet stringForColumnIndex:0] forKey:@"firstName"];
            if([resultSet stringForColumnIndex:1]!=NULL) [creator setObject:[resultSet stringForColumnIndex:1] forKey:@"lastName"];
            if([resultSet stringForColumnIndex:2]!=NULL) [creator setObject:[resultSet stringForColumnIndex:2] forKey:@"shortName"];
            [creator setObject:[resultSet stringForColumnIndex:3] forKey:@"creatorType"];
            
            [creators addObject:creator];
        }
        
        [resultSet close];
        return creators;
    }

}


- (void) addCreatorsToItem: (ZPZoteroItem*) item {
    item.creators = [self _creatorsForItem:item];
}



- (void) addFieldsToItem: (ZPZoteroItem*) item  {
    item.fields = [self _fieldsForItem:item];
}

- (void) addAttachmentsToItem: (ZPZoteroItem*) item  {
    
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery: @"SELECT key,lastTimestamp,attachmentURL,attachmentType,attachmentTitle,attachmentLength FROM attachments WHERE parentItemKey = ? AND attachmentURL IS NOT NULL",item.key];
        
        NSMutableArray* attachments = [[NSMutableArray alloc] init];
        while([resultSet next]) {
            ZPZoteroAttachment* attachment = ( ZPZoteroAttachment*) [ZPZoteroAttachment retrieveOrInitializeWithKey:[resultSet stringForColumnIndex:0]];
            attachment.lastTimestamp = [resultSet stringForColumnIndex:1];
            attachment.attachmentURL = [resultSet stringForColumnIndex:2];
            attachment.attachmentType = [resultSet stringForColumnIndex:3];
            attachment.attachmentTitle = [resultSet stringForColumnIndex:4];
            attachment.attachmentLength = [resultSet intForColumnIndex:5];
            attachment.parentItemKey = item.key;
            
            [attachments addObject:attachment];
            
        }
        
        [resultSet close];
        
        item.attachments = attachments;

    }
}

- (NSArray*) getCachedAttachmentPaths{
    
    @synchronized(self){
        
        NSMutableArray* returnArray = [NSMutableArray array];
        
        FMResultSet* resultSet = [_database executeQuery: @"SELECT key,lastTimestamp,attachmentURL,attachmentType,attachmentTitle,attachmentLength,parentItemKey FROM attachments WHERE attachmentURL IS NOT NULL ORDER BY CASE WHEN lastViewed IS NULL THEN 0 ELSE 1 end, lastViewed ASC, lastTimestamp ASC"];
        
        while([resultSet next]){
            ZPZoteroAttachment* attachment = [ZPZoteroAttachment retrieveOrInitializeWithKey:[resultSet stringForColumnIndex:0]];
            attachment.lastTimestamp = [resultSet stringForColumnIndex:1];
            attachment.attachmentURL = [resultSet stringForColumnIndex:2];
            attachment.attachmentType = [resultSet stringForColumnIndex:3];
            attachment.attachmentTitle = [resultSet stringForColumnIndex:4];
            attachment.attachmentLength = [resultSet intForColumnIndex:5];
            attachment.parentItemKey = [resultSet stringForColumnIndex:6];
            
            //If this attachment does have a file, add it to the list that we return;
            if(attachment.fileExists){
                [returnArray addObject:attachment.fileSystemPath];
            }
        }

        [resultSet close];
        
        return returnArray;
    }

}

- (NSArray*) getAttachmentThatNeedToBeDownloadedInLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey{
    @synchronized(self){

        NSMutableArray* returnArray = [NSMutableArray array];

        FMResultSet* resultSet;
        
        if(collectionKey==NULL){
            resultSet= [_database executeQuery: @"SELECT attachments.key,attachments.lastTimestamp,attachmentURL,attachmentType,attachmentTitle,attachmentLength,parentItemKey FROM attachments, items WHERE parentItemKey = items.key AND items.libraryID = ? AND attachmentURL IS NOT NULL ORDER BY attachments.lastTimestamp DESC",libraryID];
        }
        else{
            resultSet= [_database executeQuery: @"SELECT attachments.key,attachments.lastTimestamp,attachmentURL,attachmentType,attachmentTitle,attachmentLength,parentItemKey FROM attachments, collectionItems WHERE parentItemKey = itemsKey AND collectionKey = ? AND attachmentURL IS NOT NULL ORDER BY attachments.lastTimestamp DESC",collectionKey];
        }
        
        while([resultSet next]){
            ZPZoteroAttachment* attachment = [ZPZoteroAttachment retrieveOrInitializeWithKey:[resultSet stringForColumnIndex:0]];
            attachment.lastTimestamp = [resultSet stringForColumnIndex:1];
            attachment.attachmentURL = [resultSet stringForColumnIndex:2];
            attachment.attachmentType = [resultSet stringForColumnIndex:3];
            attachment.attachmentTitle = [resultSet stringForColumnIndex:4];
            attachment.attachmentLength = [resultSet intForColumnIndex:5];
            attachment.parentItemKey = [resultSet stringForColumnIndex:6];
            
            [returnArray addObject:attachment];
        }
        
        [resultSet close];

        return returnArray;

    }
    
}

- (void) updateViewedTimestamp:(ZPZoteroAttachment*)attachment{
    @synchronized(self){
        [_database executeUpdate:@"UPDATE attachments SET lastViewed = datetime('now') where key = ? ",attachment.key];
    }
}


- (void) addNotesToItem: (ZPZoteroItem*) item  {
    
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery: @"SELECT key,lastTimestamp FROM notes WHERE parentItemKey = ? ",item.key];
        
        NSMutableArray* notes = [[NSMutableArray alloc] init];
        while([resultSet next]) {
            ZPZoteroNote* note = (ZPZoteroNote*) [ZPZoteroNote retrieveOrInitializeWithKey:[resultSet stringForColumnIndex:0]];
            note.lastTimestamp = [resultSet stringForColumnIndex:1];
            note.parentItemKey = item.key;
            
            [notes addObject:note];
            
        }
        
        [resultSet close];
        
        item.notes = notes;
        
    }
}

/*
 Retrieves all item keys and note and attachment keys from the library
 */

- (NSArray*) getAllItemKeysForLibrary:(NSNumber*)libraryID{
    
    NSMutableArray* keys = [[NSMutableArray alloc] init];
    
    
    NSString* sql = @"SELECT DISTINCT key, lastTimestamp FROM items UNION SELECT key, lastTimestamp FROM attachments UNION SELECT key, lastTimestamp FROM notes ORDER BY lastTimestamp DESC";
    
    @synchronized(self){
        FMResultSet* resultSet;
        
        resultSet = [_database executeQuery: sql];
        
        while([resultSet next]) [keys addObject:[resultSet stringForColumnIndex:0]];
        
        [resultSet close];
    }
    
    return keys;
}

- (NSString*) getFirstItemKeyWithTimestamp:(NSString*)timestamp from:(NSNumber*)libraryID{
    @synchronized(self){
        FMResultSet* resultSet;
        NSString* sql = @"SELECT key FROM items WHERE lastTimestamp <= ? and libraryID = ? LIMIT 1 ORDER BY lastTimestamp DESC";
        
        resultSet = [_database executeQuery: sql, timestamp, libraryID];
        
        [resultSet next];
        NSString* ret= [resultSet stringForColumnIndex:0];
        [resultSet close];
        return ret;
    }
    
}

- (NSArray*) getItemKeysForLibrary:(NSNumber*)libraryID collectionKey:(NSString*)collectionKey
                      searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending{

    NSMutableArray* keys = [[NSMutableArray alloc] init];

    //Build the SQL query as a string first. 
    
    NSString* sql = @"SELECT DISTINCT items.key FROM items";
    
    if(collectionKey!=NULL)
        sql=[sql stringByAppendingFormat:@", collectionItems"];

    if(searchString != NULL)
        sql=[sql stringByAppendingFormat:@", fields, creators"];
    
    //Conditions

    sql=[sql stringByAppendingFormat:@" WHERE libraryID = %@",libraryID];

    if(collectionKey!=NULL)
        sql=[sql stringByAppendingFormat:@" AND collectionItems.collectionKey = '%@' and collectionItems.itemKey = items.key",collectionKey];

    if(searchString != NULL){
        //TODO: Make a more feature rich search query
        
        sql=[sql stringByAppendingFormat:@" AND ((fields.itemKey = items.key AND fields.fieldValue LIKE '%%%@%%') OR (creators.itemKey = items.key AND (creators.firstName LIKE '%%%@%%') OR (creators.lastName LIKE '%%%@%%') OR (creators.shortName LIKE '%%%@%%')))",searchString,searchString];
    }
    
    if(orderField!=NULL){
        if(sortDescending)
            sql=[sql stringByAppendingFormat:@" ORDER BY items.%@ DESC",orderField];
        else
            sql=[sql stringByAppendingFormat:@" ORDER BY items.%@ ASC",orderField];
    }
    else{
        sql=[sql stringByAppendingFormat:@" ORDER BY items.lastTimestamp DESC"];
    }
    
    
    @synchronized(self){
        FMResultSet* resultSet;
        
        resultSet = [_database executeQuery: sql];
        
        while([resultSet next]) [keys addObject:[resultSet stringForColumnIndex:0]];
        
        [resultSet close];
    }

    return keys;
}

- (NSString*) getLocalizationStringWithKey:(NSString*) key type:(NSString*) type locale:(NSString*) locale{
   
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery: @"SELECT value FROM localization WHERE  type = ? AND key =? ",type,key];
        
        [resultSet next];
        
        NSString* ret = [resultSet stringForColumnIndex:0];
        
        [resultSet close];
        
        return ret;
    }

}

@end
