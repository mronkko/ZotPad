//
//  ZPDatabase.m
//  ZotPad
//
//  This class contains all database operations.
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
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

@implementation ZPDatabase

static ZPDatabase* _instance = nil;

-(id)init
{
    self = [super init];
    
    
	NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"zotpad.sqlite"];
    

    BOOL recreateDB = ! [[NSFileManager defaultManager] fileExistsAtPath:dbPath];
    
    
    NSError* error;
    
    _database = [FMDatabase databaseWithPath:dbPath];
    
    //Prevent backing up of DB
    const char* filePath = [dbPath fileSystemRepresentation];
    const char* attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
    setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);

    [_database open];
    
    //Changing these two will affect how much info is printed in log
    [_database setTraceExecution:FALSE];
    [_database setLogsErrors:TRUE];
    
    //Read the database structure from file and create the database

    if(recreateDB){

        NSLog(@"Recreating database because it was missing");
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
        
        NSLog(@"Done recreating database");

    }
    
	return self;
}

/*
 Singleton accessor. If ZotPad is set to not use cache, prevent accessing this boject by returning NULL
 */

+(ZPDatabase*) instance {
    if([[ZPPreferences instance] useCache]){
        if(_instance == NULL){
            _instance = [[ZPDatabase alloc] init];
        }
        return _instance;
    }
    else return NULL;
}

-(void) addOrUpdateLibraries:(NSArray*)libraries{
    
    @synchronized(self){
        //Delete everything but leave my library
        [_database executeUpdate:@"DELETE FROM groups WHERE groupID != 1"];
    
    
        NSEnumerator* e = [libraries objectEnumerator];
    
        ZPZoteroLibrary* library;
    
        while ( library = (ZPZoteroLibrary*) [e nextObject]) {
        
            NSNumber* libraryID = library.libraryID;
            [_database executeUpdate:@"INSERT INTO groups (groupID, title) VALUES (?, ?)",libraryID,library.title];
        }  
    }
}


-(void) addOrUpdateCollections:(NSArray*)collections forLibrary:(NSNumber*)libraryID{

    NSMutableArray* collectionKeys;
    
    @synchronized(self){
        FMResultSet* resultSet=[_database executeQuery:@"SELECT key FROM collections WHERE libraryID = ?",libraryID];
        
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
                
        @synchronized(self){
            if(count == [collectionKeys count]){
                
                [_database executeUpdate:@"INSERT INTO collections (title, key, libraryID, parentCollectionKey,lastCompletedCacheTimestamp) VALUES (?,?,?,?,?)",collection.title,collection.collectionKey,libraryID,collection.parentCollectionKey,collection.lastCompletedCacheTimestamp];
            }
            else{
                [_database executeUpdate:@"UPDATE collections SET title=?, libraryID=?, parentCollectionKey=?,lastCompletedCacheTimestamp=? WHERE key=?",collection.title,libraryID,collection.parentCollectionKey ,collection.lastCompletedCacheTimestamp,collection.collectionKey];
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


// These remove items from the cache
- (void) removeItemsNotInArray:(NSArray*)itemKeys fromCollection:(NSString*)collectionKey inLibrary:(NSNumber*)libraryID{
    @synchronized(self){
        //This might generate a too long query
        [_database executeUpdate:[NSString stringWithFormat:@"DELETE FROM collectionItems WHERE collectionKey = ? AND itemKey NOT IN ('%@')",
                                                           [itemKeys componentsJoinedByString:@"', '"]],collectionKey];
    }

}
/*
 Attachments are purged elsewhere
 */
- (void) deleteItemsNotInArray:(NSArray*)itemKeys fromLibrary:(NSNumber*)libraryID{
    @synchronized(self){
        //This might generate a too long query
        [_database executeUpdate:[NSString stringWithFormat:@"DELETE FROM items WHERE libraryID = ? AND key NOT IN ('%@')",
                                  [itemKeys componentsJoinedByString:@"', '"]],libraryID];
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
- (NSArray*) libraries{
    NSMutableArray *returnArray = [[NSMutableArray alloc] init];
    
    //Group libraries
    @synchronized(self){
        
        FMResultSet* resultSet = [_database executeQuery:@"SELECT groupID, title,  groupID IN (SELECT DISTINCT libraryID from collections) AS hasChildren, lastCompletedCacheTimestamp FROM groups"];
		
        
        while([resultSet next]) {
            
            NSInteger libraryID = [resultSet intForColumnIndex:0];
            NSString* name = [resultSet stringForColumnIndex:1];
            BOOL hasChildren = [resultSet boolForColumnIndex:2];
            
            ZPZoteroLibrary* thisLibrary = [ZPZoteroLibrary ZPZoteroLibraryWithID:[NSNumber numberWithInt:libraryID]];
            [thisLibrary setTitle: name];
            [thisLibrary setHasChildren:hasChildren];
            [thisLibrary setLastCompletedCacheTimestamp:[resultSet stringForColumnIndex:3]];
            [returnArray addObject:thisLibrary];
        }
        [resultSet close];
        
    }
	return returnArray;
}

- (NSArray*) collectionsForLibrary : (NSNumber*)libraryID withParentCollection:(NSString*)collectionKey {
	
    
    
    NSMutableArray* returnArray;
    
	@synchronized(self){
        
        FMResultSet* resultSet;
        if(collectionKey == NULL)
            resultSet= [_database executeQuery:@"SELECT key, title, key IN (SELECT DISTINCT parentCollectionKey FROM collections WHERE libraryID=?) AS hasChildren, lastCompletedCacheTimestamp FROM collections WHERE libraryID=? AND parentCollectionKey IS NULL",libraryID,libraryID];
        
        else
            resultSet= [_database executeQuery:@"SELECT key, title, key IN (SELECT DISTINCT parentCollectionKey FROM collections WHERE libraryID=?) AS hasChildren, lastCompletedCacheTimestamp FROM collections WHERE libraryID=? AND parentCollectionKey = ?",libraryID,libraryID,collectionKey];
        
        
        
        returnArray = [[NSMutableArray alloc] init];
        
        while([resultSet next]) {
            
            
            ZPZoteroCollection* thisCollection = [ZPZoteroCollection ZPZoteroCollectionWithKey:[resultSet stringForColumnIndex:0]];
            [thisCollection setLibraryID : libraryID];
            [thisCollection setTitle : [resultSet stringForColumnIndex:1]];
            [thisCollection setHasChildren:(BOOL) [resultSet intForColumnIndex:2]];
            [thisCollection setLastCompletedCacheTimestamp:[resultSet stringForColumnIndex:3]];
            
            [returnArray addObject:thisCollection];
            
        }
        [resultSet close];
        
        
	}
    
	return returnArray;
}


- (NSArray*) allCollectionsForLibrary:(NSNumber*)libraryID{	

    NSMutableArray* returnArray;
    
    //TODO: Refactor: Make a method that takes a row from resulset and then creates an object from it.
    // resultDict method in FMResultSet is probably useful for this
    
	@synchronized(self){
        FMResultSet* resultSet = [_database executeQuery:@"SELECT key, lastCompletedCacheTimestamp FROM collections WHERE libraryID=?",libraryID];
        
        
        
        returnArray = [[NSMutableArray alloc] init];
        
        while([resultSet next]) {
            ZPZoteroCollection* thisCollection = [ZPZoteroCollection ZPZoteroCollectionWithKey:[resultSet stringForColumnIndex:0]];
            [thisCollection setLastCompletedCacheTimestamp:[resultSet stringForColumnIndex:1]];
            [returnArray addObject:thisCollection];
            
        }
        [resultSet close];
	}
    
	return returnArray;
}


-(void) addItemToDatabase:(ZPZoteroItem*)item {
    
    @synchronized(self){
        //TODO: Implement modifying already existing items if they are older (lastTimestamp) nthan the new item
        FMResultSet* resultSet = [_database executeQuery: @"SELECT lastTimestamp FROM items WHERE key =? LIMIT 1",item.key];

        BOOL found = [resultSet next];
        NSString* timestamp = [resultSet stringForColumnIndex:0];
        
        [resultSet close];
        
        NSNumber* year;
        if(item.year!=0){
            year=[NSNumber numberWithInt:item.year];
        }
        else{
            year=NULL;
        }

        
        if(! found ){
            
                       
            
            [_database executeUpdate:@"INSERT INTO items (itemType,libraryID,year,creator,title,publishedIn,key,fullCitation,lastTimestamp) VALUES (?,?,?,?,?,?,?,?,?)",item.itemType,item.libraryID,year,item.creatorSummary,item.title,item.publishedIn,item.key,item.fullCitation,item.lastTimestamp];
            
        }
        //TODO: consider how the time stamp could be used to determine if fields need to be updated
        else if(! [item.lastTimestamp isEqualToString: timestamp]){
            [_database executeUpdate:@"UPDATE items SET itemType = ?, libraryID = ?, year = ?,creator =? ,title = ?,publishedIn = ?,fullCitation =?,lastTimestamp = ? WHERE key = ?",item.itemType,item.libraryID,year,item.creatorSummary,item.title,item.publishedIn,item.fullCitation,item.lastTimestamp,item.key];
        }
        
    }
}

-(void) addNoteToDatabase:(ZPZoteroNote*)note{
    //For now ignore standalone notes
    if(note.parentItemKey !=NULL){
        @synchronized(self){
            //TODO: Implement modifying already existing items if they are older (lastTimestamp) nthan the new note
            FMResultSet* resultSet = [_database executeQuery: @"SELECT lastTimestamp FROM notes WHERE key =? LIMIT 1",note.key];
            
            BOOL found = [resultSet next];
            
            [resultSet close];
            
            if(! found ){
                [_database executeUpdate:@"INSERT INTO notes (key,parentItemKey,lastTimestamp) VALUES (?,?,?)",note.key,note.parentItemKey,note.lastTimestamp];
            }
        }
    }
}

-(void) addAttachmentToDatabase:(ZPZoteroAttachment*)attachment{

    @synchronized(self){
        //TODO: Implement modifying already existing items if they are older (lastTimestamp) nthan the new item
        FMResultSet* resultSet = [_database executeQuery: @"SELECT lastTimestamp FROM attachments WHERE key =? LIMIT 1",attachment.key];
        
        BOOL found = [resultSet next];
        
        [resultSet close];
        
        if(! found ){
            
            
            [_database executeUpdate:@"INSERT INTO attachments (key,parentItemKey,lastTimestamp,attachmentURL,attachmentType,attachmentTitle,attachmentLength) VALUES (?,?,?,?,?,?,?)",
             attachment.key,attachment.parentItemKey,attachment.lastTimestamp,attachment.attachmentURL,attachment.attachmentType,attachment.attachmentTitle,[NSNumber numberWithInt: attachment.attachmentLength]];
            
        }
    }
}


// Records a new collection membership
-(void) addItem:(ZPZoteroItem*)item toCollection:(NSString*)collectionKey{
    //TODO: Make this check if an item exists in a collection before running this
    @synchronized(self){
        [_database executeUpdate:@"INSERT INTO collectionItems (collectionKey, itemKey) VALUES (?,?)",collectionKey,item.key];

    }
}




- (void) addBasicToItem:(ZPZoteroItem *)item{
    
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
            [_database executeUpdate:@"INSERT INTO creators (itemKey,\"order\",firstName,lastName,shortName,creatorType) VALUES (?,?,?,?,?,?)",
                                      item.key,[NSNumber numberWithInt:order],[creator objectForKey:@"firstName"],[creator objectForKey:@"lastName"],
                                      [creator objectForKey:@"shortName"],[creator objectForKey:@"creatorType"]];
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
        FMResultSet* resultSet = [_database executeQuery: @"SELECT firstName, lastName, shortName,creatorType, fieldMode FROM creators WHERE itemKey = ? ORDER BY \"order\"",item.key];
        
        NSMutableArray* creators = [[NSMutableArray alloc] init];
        
        while([resultSet next]) {
            NSMutableDictionary* creator = [[NSMutableDictionary alloc] init];
            
            if([resultSet stringForColumnIndex:0]!=NULL) [creator setObject:[resultSet stringForColumnIndex:0] forKey:@"firstName"];
            if([resultSet stringForColumnIndex:1]!=NULL) [creator setObject:[resultSet stringForColumnIndex:1] forKey:@"lastName"];
            if([resultSet stringForColumnIndex:2]!=NULL) [creator setObject:[resultSet stringForColumnIndex:2] forKey:@"shortName"];
            [creator setObject:[resultSet stringForColumnIndex:3] forKey:@"creatorType"];
            
            //TODO: Would this be needed at all?
            //[creator setObject:[NSNumber numberWithInt:[resultSet intForColumnIndex:4]] forKey:@"fieldMode"];
            
            [creators addObject:creator];
        }
        
        [resultSet close];
        item.creators = creators;
    }
}



- (void) addFieldsToItem: (ZPZoteroItem*) item  {
    
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery: @"SELECT fieldName, fieldValue FROM fields WHERE itemKey = ? ",item.key];
        
        NSMutableDictionary* fields = [[NSMutableDictionary alloc] init];
        while([resultSet next]) {
            
            [fields setObject:[resultSet stringForColumnIndex:1] forKey:[resultSet stringForColumnIndex:0]];
        }
        
        [resultSet close];
        
        if([fields count]>0) item.fields = fields;
        else item.fields = NULL;
    }
}

- (void) addAttachmentsToItem: (ZPZoteroItem*) item  {
    
    @synchronized(self){
        FMResultSet* resultSet = [_database executeQuery: @"SELECT key,lastTimestamp,attachmentURL,attachmentType,attachmentTitle,attachmentLength FROM attachments WHERE parentItemKey = ? ",item.key];
        
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
        
        FMResultSet* resultSet = [_database executeQuery: @"SELECT key,lastTimestamp,attachmentURL,attachmentType,attachmentTitle,attachmentLength,parentItemKey FROM attachments ORDER BY CASE WHEN lastViewed IS NULL THEN 0 ELSE 1 end, lastViewed ASC, lastTimestamp ASC"];
        
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
            resultSet= [_database executeQuery: @"SELECT attachments.key,attachments.lastTimestamp,attachmentURL,attachmentType,attachmentTitle,attachmentLength,parentItemKey FROM attachments, items WHERE parentItemKey = items.key AND items.libraryID = ? ORDER BY attachments.lastTimestamp DESC",libraryID];
        }
        else{
            resultSet= [_database executeQuery: @"SELECT attachments.key,attachments.lastTimestamp,attachmentURL,attachmentType,attachmentTitle,attachmentLength,parentItemKey FROM attachments, collectionItems WHERE parentItemKey = itemsKey AND collectionKey = ? ORDER BY attachments.lastTimestamp DESC",collectionKey];
        }
        
        while([resultSet next]){
            ZPZoteroAttachment* attachment = [ZPZoteroAttachment retrieveOrInitializeWithKey:[resultSet stringForColumnIndex:0]];
            attachment.lastTimestamp = [resultSet stringForColumnIndex:1];
            attachment.attachmentURL = [resultSet stringForColumnIndex:2];
            attachment.attachmentType = [resultSet stringForColumnIndex:3];
            attachment.attachmentTitle = [resultSet stringForColumnIndex:4];
            attachment.attachmentLength = [resultSet intForColumnIndex:5];
            attachment.parentItemKey = [resultSet stringForColumnIndex:6];
            
            //If this attachment does have a file, add it to the list that we return;
            if(! attachment.fileExists){
                [returnArray addObject:attachment];
            }
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
        FMResultSet* resultSet = [_database executeQuery: @"SELECT key,lastTimestamp FROM attachments WHERE parentItemKey = ? ",item.key];
        
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

- (NSArray*) getItemKeysForLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey
                      searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending{

    NSMutableArray* keys = [[NSMutableArray alloc] init];

    //Build the SQL query as a string first. This currently searches only in the full citation.

    NSString* sql = @"SELECT items.key FROM items";
    
    if(collectionKey!=NULL)
        sql=[sql stringByAppendingFormat:@", collectionItems"];

    if(searchString != NULL)
        sql=[sql stringByAppendingFormat:@", fields"];
    
    //Conditions

    sql=[sql stringByAppendingFormat:@" WHERE libraryID = %@",libraryID];

    if(collectionKey!=NULL)
        sql=[sql stringByAppendingFormat:@" AND collectionItems.collectionKey = %@ and collectionItems.itemKey = items.key",collectionKey];

    if(searchString != NULL){
        //TODO: Handle quotes
        NSArray* searchArray = [searchString componentsSeparatedByString:@" "];
        
        sql=[sql stringByAppendingFormat:@" AND field.itemKey = items.key AND (field.fieldValue LIKE '\%%@\%)'",[searchArray componentsJoinedByString:@"%' OR field.fieldValue LIKE '%"]];
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
