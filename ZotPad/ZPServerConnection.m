//
//  ZPServerConnection.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//



#include <sys/xattr.h>

#import "ZPCore.h"
#import "ZPServerConnection.h"

#import "ZPAppDelegate.h"

#import "ZPAuthenticationDialog.h"

#import "ZPServerResponseXMLParser.h"
#import "ZPServerResponseXMLParserKeyPermissions.h"
#import "ZPServerResponseXMLParserItem.h"
#import "ZPServerResponseXMLParserLibrary.h"
#import "ZPServerResponseXMLParserCollection.h"

#import "ASIHTTPRequest.h"
#import "ZPReachability.h"

#import "ZPItemDataDownloadManager.h"

//Needed for creating JSON items for write API
#import "ZPZoteroItemTypes.h"
#import "SBJson.h"

#pragma mark - UIAlertView delegate

@interface ZPAutenticationErrorAlertViewDelegate : NSObject <UIAlertViewDelegate>;
@end

@implementation ZPAutenticationErrorAlertViewDelegate

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    if(buttonIndex == 0){
        //Stay offline button, do nothing
    }
    else if(buttonIndex == 1){
        [[UIApplication sharedApplication] openURL:[NSString stringWithFormat:@"https://www.zotero.org/settings/keys/edit/%@",[ZPPreferences OAuthKey]]];
    }
    else if(buttonIndex == 2 ){
        //New key button
        [ZPPreferences resetUserCredentials];
        [ZPPreferences setOnline:TRUE];
    }
}


@end

@interface ZPConnectionErrorAlertViewDelegate : NSObject <UIAlertViewDelegate>;
@end

@implementation ZPConnectionErrorAlertViewDelegate

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    if(buttonIndex == 0){
        //Stay offline button, do nothing
    }
    else if(buttonIndex == 1){
        [ZPPreferences setOnline:TRUE];
    }
}


@end




//Private methods



@interface ZPServerConnection()
    
+(void) _makeServerRequest:(NSInteger)type withParameters:(NSDictionary*) parameters userInfo:(NSDictionary*)userInfo usingOperationQueue:(NSOperationQueue*)queue completion:(void(^)(NSArray*))completionBlock;
+(void) _makeServerRequest:(NSInteger)type withParameters:(NSDictionary*) parameters userInfo:(NSDictionary*)userInfo completion:(void(^)(NSArray*))completionBlock;

+(void) _makeServerRequest:(NSInteger)type withParameters:(NSDictionary*) parameters userInfo:(NSDictionary*)userInfo usingOperationQueue:(NSOperationQueue*)queue;
+(void) _makeServerRequest:(NSInteger)type withParameters:(NSDictionary*) parameters userInfo:(NSDictionary*)userInfo;

+(NSString*) _baseURLWithLibraryID:(NSInteger)libraryID;

+(void) _performRequest:(ASIHTTPRequest*)request usingOperationQueue:(NSOperationQueue*)queue completion:(void(^)(NSData*))completionBlock;

+(ZPServerResponseXMLParser*) _parseXMLResponseData:(NSData*)responseData requestType:(NSInteger) type;

+(void) _processParsedResponse:(ZPServerResponseXMLParser*)parserDelegate requestType:(NSInteger) type userInfo:(NSDictionary*) userInfo;

+(NSString*) _tagsJSSONForDataObject:(ZPZoteroDataObject*) dataObject;
+(NSString*) _JSONEscapeString:(NSString*) string;

@end


@implementation ZPServerConnection

static ZPAutenticationErrorAlertViewDelegate* alertViewDelegate;
static NSOperationQueue* _addHocKeyRetrievals;
static NSOperationQueue* _writeRequestQueue;

const NSInteger ZPServerConnectionRequestGroups = 1;
const NSInteger ZPServerConnectionRequestCollections = 2;
const NSInteger ZPServerConnectionRequestSingleCollection = 3;
const NSInteger ZPServerConnectionRequestItems = 4;
const NSInteger ZPServerConnectionRequestItemsAndChildren = 5;
const NSInteger ZPServerConnectionRequestSingleItem = 6;
const NSInteger ZPServerConnectionRequestSingleItemChildren = 7;
const NSInteger ZPServerConnectionRequestKeys = 8;
const NSInteger ZPServerConnectionRequestTopLevelKeys = 9;
const NSInteger ZPServerConnectionRequestPermissions = 10;
const NSInteger ZPServerConnectionRequestLastModifiedItem = 11;

+(void) initialize
{    
    _addHocKeyRetrievals = [[NSOperationQueue alloc] init];
    [_addHocKeyRetrievals setMaxConcurrentOperationCount:3];

    _writeRequestQueue = [[NSOperationQueue alloc] init];
    [_writeRequestQueue setMaxConcurrentOperationCount:1];
    
    

}

/*
 We assume that the client is authenticated if a oauth key exists. The key will be cleared if we notice that it is not valid while using it.
 */

+(BOOL) authenticated{
    
    return([ZPPreferences OAuthKey] != nil);
    
}

+(NSInteger) numberOfActiveMetadataRequests{
    return [[ASIHTTPRequest sharedQueue] operationCount];
}

#pragma mark - Read API calls

+(void) retrieveSingleItem:(ZPZoteroAttachment*)item completion:(void(^)(NSArray*))completionBlock{
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:item.libraryID] forKey:ZPKEY_LIBRARY_ID];

    [parameters setObject:item.key forKey:ZPKEY_ITEM_KEY];
    [parameters setObject:@"json" forKey:@"content"];
    
    [self _makeServerRequest:ZPServerConnectionRequestSingleItem withParameters:parameters userInfo:NULL completion:completionBlock];
    
}

+(void) retrieveSingleItemAndChildrenFromServer:(ZPZoteroItem*)item{

    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:item.libraryID] forKey:ZPKEY_LIBRARY_ID];
    [parameters setObject:item.key forKey:ZPKEY_ITEM_KEY];

    if([ZPPreferences debugCitationParser]){
        [parameters setObject:@"json,bib" forKey:@"content"];
        [parameters setObject:@"apa" forKey:@"style"];
    }
    else{
        [parameters setObject:@"json" forKey:@"content"];
    }

    [self _makeServerRequest:ZPServerConnectionRequestSingleItem withParameters:parameters userInfo:NULL];
    [self _makeServerRequest:ZPServerConnectionRequestSingleItemChildren withParameters:parameters userInfo:NULL];

    /*
    NSArray* parsedArray = [parserDelegate parsedElements];
    
    if(parserDelegate == NULL || [parsedArray count] == 0 ) return NULL;
    
    item = [parsedArray objectAtIndex:0];   

    //Request attachments for the single item

    if(item.numChildren >0){
        [parameters setObject:@"json" forKey:@"content"];
        parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestSingleItemChildren withParameters:parameters];
        
        NSMutableArray* attachments = NULL;
        NSMutableArray* notes = NULL;
        
        for(NSObject* child in [parserDelegate parsedElements] ){
            if([child isKindOfClass:[ZPZoteroAttachment class]]){
                if(attachments == NULL) attachments = [NSMutableArray array];
               [attachments addObject:child];
            }
            else if([child isKindOfClass:[ZPZoteroNote class]]){
                if(notes == NULL) notes = [NSMutableArray array];
                [notes addObject:child];
            }
        }
        
         
        if(notes != NULL) item.notes = notes;
        else item.notes = [NSArray array];
        
        if(attachments != NULL){
            [attachments sortUsingDescriptors:[NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"title" ascending:TRUE]]];
            if(![attachments isEqual:item.attachments]){
                item.attachments = attachments;   
            }
        }
        else item.attachments = [NSArray array];
    
    }
    return item;
     */
}

+(void) retrieveLibrariesFromServer{

    [self _makeServerRequest:ZPServerConnectionRequestGroups withParameters:NULL userInfo:NULL];
    
    /*
    //Retrieve access rights of this key
    NSArray* librariesThatCanBeAccessed = [[self makeServerRequest:ZPServerConnectionRequestPermissions withParameters:NULL] parsedElements];
    
    if([librariesThatCanBeAccessed count]==0) return NULL;
    
    
    //Retrieve all groups from the server

    ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestGroups withParameters:NULL];

    NSArray* returnArray = [parserDelegate parsedElements];
 
    if(parserDelegate == NULL) return NULL;
    
    //If there is more data coming, retrieve it
    while([returnArray count] < parserDelegate.totalResults){

        NSMutableDictionary* parameters=[[NSMutableDictionary alloc] initWithCapacity:1];
        [parameters setObject:[NSString stringWithFormat:@"%i",[returnArray count]] forKey:@"start"];

        ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestGroups withParameters:parameters];

        if(parserDelegate == NULL) return NULL;
        
        NSArray* returnArray = [parserDelegate parsedElements];

        returnArray=[returnArray arrayByAddingObjectsFromArray:parserDelegate.parsedElements];
    }
    
    //Are group specifid permissions in use
    
    if([librariesThatCanBeAccessed indexOfObject:@"all"]==NSNotFound){
        NSMutableArray* newArray= [[NSMutableArray alloc] init];
        
        //enumerate through the permissions and build list of libraries
        NSString* libraryID;
        for(libraryID in librariesThatCanBeAccessed){
            [newArray addObject:[ZPZoteroLibrary libraryWithID:[libraryID intValue]]];
        }
        returnArray = newArray;
    }
    
    //Is my library available
    else if([librariesThatCanBeAccessed indexOfObject:[NSString stringWithFormat:@"%i",LIBRARY_ID_MY_LIBRARY]]!=NSNotFound){
        returnArray = [[NSArray arrayWithObject:[ZPZoteroLibrary libraryWithID:LIBRARY_ID_MY_LIBRARY]] arrayByAddingObjectsFromArray:returnArray];
    }
            
    return returnArray;
    */
}

+(void) retrieveCollectionsForLibraryFromServer:(NSInteger)libraryID{
    //NSLog(@"Requesting collections for %i",libraryID);
    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:libraryID] forKey:ZPKEY_LIBRARY_ID];
    [self _makeServerRequest:ZPServerConnectionRequestCollections withParameters:parameters userInfo:parameters];
}

+(void) retrieveCollection:(NSString*)collectionKey fromLibrary:(NSInteger)libraryID{

    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:libraryID] forKey:ZPKEY_LIBRARY_ID];
    [parameters setValue:collectionKey forKey:ZPKEY_COLLECTION_KEY];
    [self _makeServerRequest:ZPServerConnectionRequestSingleCollection withParameters:parameters userInfo:parameters];

}


+(void) retrieveItemsFromLibrary:(NSInteger)libraryID itemKeys:(NSArray*)keys {
    
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:libraryID]  forKey:ZPKEY_LIBRARY_ID];
    
    if([ZPPreferences debugCitationParser]){
        [parameters setObject:@"json,bib" forKey:@"content"];
        [parameters setObject:@"apa" forKey:@"style"];
    }
    else{
        [parameters setObject:@"json" forKey:@"content"];
    }
        
    [parameters setObject:[keys componentsJoinedByString:@","] forKey:ZPKEY_ITEM_KEY];
        
    [self _makeServerRequest:ZPServerConnectionRequestItemsAndChildren withParameters:parameters userInfo:NULL];
    
    
}
+(void) retrieveAllItemKeysFromLibrary:(NSInteger)libraryID{
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:libraryID]  forKey:ZPKEY_LIBRARY_ID];
    [parameters setObject:@"dateModified" forKey:ZPKEY_SORT_COLUMN];
    [parameters setObject:@"desc" forKey:ZPKEY_ORDER_DIRECTION];

    NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:[NSNumber numberWithInt:libraryID] forKey:ZPKEY_LIBRARY_ID];

    [self _makeServerRequest:ZPServerConnectionRequestKeys withParameters:parameters userInfo:userInfo];
    
}

+(void) retrieveKeysInLibrary:(NSInteger)libraryID collection:(NSString*)key{
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:libraryID]  forKey:ZPKEY_LIBRARY_ID];
    if(key!=NULL) [parameters setValue:key forKey:ZPKEY_COLLECTION_KEY];

    NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:[NSNumber numberWithInt:libraryID] forKey:ZPKEY_LIBRARY_ID];
    if(key!=NULL)  [userInfo setObject:key forKey:ZPKEY_COLLECTION_KEY];
    
    [self _makeServerRequest:ZPServerConnectionRequestTopLevelKeys withParameters:parameters userInfo:userInfo];
}

+(void) retrieveKeysInLibrary:(NSInteger)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString tags:(NSArray*)tags orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending{
    
    //This method should be called only from the user interface (i.e. the main thread)
    
    if(![NSThread isMainThread]) [NSException raise:@"Called key retrieval method from non-UI thread" format:@"This method is meant for ad-hoc item key retrievals from the user interface and should not be used for any other purpose"];
    [_addHocKeyRetrievals cancelAllOperations];
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:libraryID]  forKey:ZPKEY_LIBRARY_ID];

    if(collectionKey!=NULL) [parameters setValue:collectionKey forKey:ZPKEY_COLLECTION_KEY];
    
    //Search
    if(searchString!=NULL && ! [searchString isEqualToString:@""]){
        [parameters setObject:searchString forKey: ZPKEY_SEARCH_STRING];
    }
    //Tags
    if(tags!=NULL && [tags count]>0){
        // OR tags
        //[parameters setObject:[tags componentsJoinedByString:@" || "] forKey: ZPKEY_TAG];
        [parameters setObject:[tags componentsJoinedByString:@"&tag="] forKey: ZPKEY_TAG];
    }
    //Sort
    if(orderField!=NULL){
        [parameters setObject:orderField forKey:ZPKEY_SORT_COLUMN];
        
        if(sortDescending){
            [parameters setObject:@"desc" forKey:ZPKEY_ORDER_DIRECTION];
        }
        else{
            [parameters setObject:@"asc" forKey:ZPKEY_ORDER_DIRECTION];
        }
    }
    //Get the most recent first by default
    else{
        [NSException raise:@"Sort must be specified" format:@"Item key requests from user interface must specify sort field and direction"];
    }
    
    //Store the tags as arry in userInfo
    NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [userInfo setObject:tags forKey:ZPKEY_TAG];
    
    [self _makeServerRequest:ZPServerConnectionRequestTopLevelKeys withParameters:parameters userInfo:userInfo usingOperationQueue:_addHocKeyRetrievals];
    
}

+(void) retrieveTimestampForLibrary:(NSInteger)libraryID collection:(NSString*)key{
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:libraryID]  forKey:ZPKEY_LIBRARY_ID];
    if(key!=NULL) [parameters setValue:key forKey:ZPKEY_COLLECTION_KEY];
    
    NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:[NSNumber numberWithInt:libraryID] forKey:ZPKEY_LIBRARY_ID];
    if(key!=NULL)  [userInfo setObject:key forKey:ZPKEY_COLLECTION_KEY];
    
    [self _makeServerRequest:ZPServerConnectionRequestLastModifiedItem withParameters:parameters userInfo:userInfo];
}

#pragma mark - Write API calls

//Write API requests


+(void) createCollection:(ZPZoteroCollection*)collection completion:(void(^)(ZPZoteroCollection*))completionBlock{


    NSString* urlString = [[self _baseURLWithLibraryID:collection.libraryID] stringByAppendingFormat:@"collections?key=%@",[ZPPreferences OAuthKey]];
    
    ASIHTTPRequest* postRequest = [[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    postRequest.requestMethod = @"POST";
    
    [postRequest addRequestHeader:@"Content-Type" value:@"application/json"];
    [postRequest addRequestHeader:@"X-Zotero-Write-Token" value:collection.collectionKey];

    NSString* parentString;
    if(collection.parentKey == nil){
        parentString = @"false";
    }
    else{
        parentString = [NSString stringWithFormat:@"\"%@\"",collection.parentKey];
    }
    [postRequest appendPostData:[[NSString stringWithFormat:@"{\"name\":\"%@\",\"parent\":%@}",collection.title,parentString] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [self _performRequest:postRequest usingOperationQueue:_writeRequestQueue completion:^(NSData* responseData){
       
        NSXMLParser* parser = [[NSXMLParser alloc] initWithData:responseData];
        ZPServerResponseXMLParser* parserDelegate =  [[ZPServerResponseXMLParserCollection alloc] init];
        parser.delegate = parserDelegate;
        [parser parse];
        completionBlock([parserDelegate.parsedElements objectAtIndex:0]);
    }];
}

+(void) addItems:(NSArray*)itemKeys toCollection:(ZPZoteroCollection*)collection completion:(void(^)(void))completionBlock{

    NSString* urlString = [[self _baseURLWithLibraryID:collection.libraryID] stringByAppendingFormat:@"collections/%@/items?key=%@", collection.key,[ZPPreferences OAuthKey]];
    
    ASIHTTPRequest* postRequest = [[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    postRequest.requestMethod = @"POST";

    [postRequest appendPostData:[[itemKeys componentsJoinedByString:@" "]dataUsingEncoding: NSUTF8StringEncoding]];
    
    [self _performRequest:postRequest usingOperationQueue:_writeRequestQueue completion:^(NSData* responseData){
        completionBlock();
    }];
    
}


+(void) removeItem:(NSString*)itemKey fromCollection:(ZPZoteroCollection*)collection completion:(void(^)(void))completionBlock{

    NSString* urlString = [[self _baseURLWithLibraryID:collection.libraryID] stringByAppendingFormat:@"collections/%@/items/%@?key=%@", collection.key,itemKey, [ZPPreferences OAuthKey]];
    
    ASIHTTPRequest* deleteRequest = [[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    deleteRequest.requestMethod = @"DELETE";
    
    [self _performRequest:deleteRequest usingOperationQueue:_writeRequestQueue completion:^(NSData* responseData){
        completionBlock();
    }];
    
}

+(void) editAttachment:(ZPZoteroAttachment*)attachment completion:(void(^)(ZPZoteroAttachment*))completionBlock{
 
    NSString* urlString = [[self _baseURLWithLibraryID:attachment.libraryID] stringByAppendingFormat:@"items/%@?key=%@", attachment.itemKey, [ZPPreferences OAuthKey]];
    
    ASIHTTPRequest* postRequest = [[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    postRequest.requestMethod = @"PUT";
    
    [postRequest addRequestHeader:@"Content-Type" value:@"application/json"];
    [postRequest addRequestHeader:@"If-Match" value:attachment.etag];
    
    NSString* linkMode ;
    
    if(attachment.linkMode == LINK_MODE_IMPORTED_FILE) linkMode = @"imported_file";
    else if (attachment.linkMode == LINK_MODE_IMPORTED_URL) linkMode = @"imported_url";
    else if (attachment.linkMode == LINK_MODE_LINKED_URL) linkMode = @"linked_url";
    else if (attachment.linkMode == LINK_MODE_LINKED_FILE) linkMode = @"linked_file";
    
    NSString* json = [NSString stringWithFormat:@"{\"itemType\":\"attachment\",\"linkMode\":\"%@\",\"title\":\"%@\",\"accessDate\":\"%@\",\"url\":\"%@\",\"note\":\"%@\",\"contentType\":\"%@\",\"charset\":\"%@\",\"filename\":\"%@\",\"md5\":%@,\"mtime\":\%@,\"tags\":%@}", linkMode, [self _JSONEscapeString:attachment.title],
                      attachment.accessDate == nil ? @"": attachment.accessDate,
                      attachment.url == nil ? @"": [self _JSONEscapeString:attachment.url],
                      [self _JSONEscapeString:attachment.note],
                      attachment.contentType == nil ? @"": attachment.contentType,
                      attachment.charset == nil ? @"": attachment.charset,
                      [self _JSONEscapeString:attachment.filename],
                      attachment.md5 == nil ? @"null": [NSString stringWithFormat:@"\"%@\"",attachment.md5],
                      attachment.mtime == 0 ? @"null": [NSString stringWithFormat:@"%lli",attachment.mtime],
                      [self _tagsJSSONForDataObject:attachment]];
    
    DDLogVerbose(@"Posting attachment JSON to server. Etag: %@ \n%@", attachment.etag, json);

    [postRequest appendPostData:[json dataUsingEncoding:NSUTF8StringEncoding]];
    
    [self _performRequest:postRequest usingOperationQueue:_writeRequestQueue completion:^(NSData* responseData){
        
        NSXMLParser* parser = [[NSXMLParser alloc] initWithData:responseData];
        ZPServerResponseXMLParser* parserDelegate =  [[ZPServerResponseXMLParserItem alloc] init];
        parser.delegate = parserDelegate;
        [parser parse];
        completionBlock([parserDelegate.parsedElements objectAtIndex:0]);
    }];

}

+(void) editItem:(ZPZoteroItem *)item completion:(void (^)(ZPZoteroItem *))completionBlock{
    
    NSString* urlString = [[self _baseURLWithLibraryID:item.libraryID] stringByAppendingFormat:@"items/%@?key=%@", item.itemKey, [ZPPreferences OAuthKey]];
    
    ASIHTTPRequest* postRequest = [[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    postRequest.requestMethod = @"PUT";
    
    [postRequest addRequestHeader:@"Content-Type" value:@"application/json"];
    [postRequest addRequestHeader:@"If-Match" value:item.etag];
    
    NSMutableString* json = [NSMutableString stringWithFormat:@"{\"itemType\":\"%@\",", item.itemType];
    
    for(NSString* field in [ZPZoteroItemTypes fieldsForItemType:item.itemType]){
        
        if([field isEqualToString:@"creator"]){
            [json appendString:@"\"creators\":[" ];

            BOOL firstCreator = TRUE;
            
            for(NSDictionary* creator in item.creators){
                
                if(! firstCreator) [json appendString:@", "];
                firstCreator = FALSE;
                
                [json appendFormat:@"{\"creatorType\": \"%@\"",[creator objectForKey:@"creatorType"]];
                
                NSString* name = [creator objectForKey:@"name"];
                if(name != [NSNull null]){
                    [json appendFormat:@", \"name\": \"%@\"",name];
                }
                else{
                    [json appendFormat:@", \"lastName\": \"%@\"",[creator objectForKey:@"lastName"]];
                    [json appendFormat:@", \"firstName\": \"%@\"",[creator objectForKey:@"firstName"]];
                }
                [json appendString:@"}"];
            }
            [json appendString:@"]"];
            
        }
        else{
            NSString* value;
            if([item respondsToSelector:NSSelectorFromString(field)]){
                value = [item performSelector:NSSelectorFromString(field)];
            }
            else{
                value = [item.fields objectForKey:field];
            }
            [json appendFormat:@"\"%@\": \"%@\"",field,[self _JSONEscapeString:value]];
            
            
        }
        
        [json appendString:@", "];
    }
    
    // Tags
    [json appendString:@"\"tags\":"];
    [json appendString:[self _tagsJSSONForDataObject:item]];

    [json appendString:@"}"];
    
    DDLogVerbose(@"Posting item JSON to server. Etag: %@ \n%@", item.etag, json);
    
    [postRequest appendPostData:[json dataUsingEncoding:NSUTF8StringEncoding]];
    
    [self _performRequest:postRequest usingOperationQueue:_writeRequestQueue completion:^(NSData* responseData){
        
        NSXMLParser* parser = [[NSXMLParser alloc] initWithData:responseData];
        ZPServerResponseXMLParser* parserDelegate =  [[ZPServerResponseXMLParserItem alloc] init];
        parser.delegate = parserDelegate;
        [parser parse];
        completionBlock([parserDelegate.parsedElements objectAtIndex:0]);
    }];
    
}


+(void) createNote:(ZPZoteroNote*)note completion:(void(^)(ZPZoteroNote*))completionBlock{

    NSString* urlString = [[self _baseURLWithLibraryID:note.libraryID] stringByAppendingFormat:@"items/%@/children?key=%@", note.parentKey, [ZPPreferences OAuthKey]];
    
    ASIHTTPRequest* postRequest = [[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    postRequest.requestMethod = @"POST";
    
    [postRequest addRequestHeader:@"Content-Type" value:@"application/json"];
    [postRequest addRequestHeader:@"X-Zotero-Write-Token" value:note.itemKey];

    NSString* json = [NSString stringWithFormat:@"{\"items\" : [{  \"itemType\" : \"note\",  \"note\" : \"%@\",  \"tags\" : []}]}",note.note];
    
    [postRequest appendPostData:[json dataUsingEncoding:NSUTF8StringEncoding]];
    
    [self _performRequest:postRequest usingOperationQueue:_writeRequestQueue completion:^(NSData* responseData){
        
        NSXMLParser* parser = [[NSXMLParser alloc] initWithData:responseData];
        ZPServerResponseXMLParser* parserDelegate =  [[ZPServerResponseXMLParserItem alloc] init];
        parser.delegate = parserDelegate;
        [parser parse];
        completionBlock([parserDelegate.parsedElements objectAtIndex:0]);
    }];

}

+(void) editNote:(ZPZoteroNote*)note completion:(void(^)(ZPZoteroNote*))completionBlock{

    NSString* urlString = [[self _baseURLWithLibraryID:note.libraryID] stringByAppendingFormat:@"items/%@?key=%@", note.itemKey, [ZPPreferences OAuthKey]];
    
    ASIHTTPRequest* postRequest = [[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    postRequest.requestMethod = @"PUT";
    
    [postRequest addRequestHeader:@"Content-Type" value:@"application/json"];
    [postRequest addRequestHeader:@"If-Match" value:note.etag];
    
    [postRequest appendPostData:[[NSString stringWithFormat:@"{  \"itemType\" : \"note\",  \"note\" : \"%@\",  \"tags\" : [], \"creators\" : []}",note.note] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [self _performRequest:postRequest usingOperationQueue:_writeRequestQueue completion:^(NSData* responseData){
        
        NSXMLParser* parser = [[NSXMLParser alloc] initWithData:responseData];
        ZPServerResponseXMLParser* parserDelegate =  [[ZPServerResponseXMLParserItem alloc] init];
        parser.delegate = parserDelegate;
        [parser parse];
        completionBlock([parserDelegate.parsedElements objectAtIndex:0]);
    }];
    
}

+(void) deleteNote:(ZPZoteroNote*)note completion:(void(^)(void))completionBlock{

    NSString* urlString = [[self _baseURLWithLibraryID:note.libraryID] stringByAppendingFormat:@"items/%@?key=%@", note.itemKey, [ZPPreferences OAuthKey]];
    
    ASIHTTPRequest* postRequest = [[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    postRequest.requestMethod = @"DELETE";
    
    [postRequest addRequestHeader:@"If-Match" value:note.etag];
    
    [self _performRequest:postRequest usingOperationQueue:_writeRequestQueue completion:^(NSData* responseData){
        completionBlock();
    }];
    
}

+(NSInteger) numberOfActiveMetadataWriteRequests{
    return [_writeRequestQueue operationCount];
}

# pragma mark - Internal methods

+(NSString*) _baseURLWithLibraryID:(NSInteger)libraryID{
 
    if(libraryID== LIBRARY_ID_MY_LIBRARY || libraryID == LIBRARY_ID_NOT_SET){
        return [NSString stringWithFormat:@"https://api.zotero.org/users/%@/",[ZPPreferences userID]];
    }
    else{
        return [NSString stringWithFormat:@"https://api.zotero.org/groups/%i/",libraryID];
    }

}

+(void) _makeServerRequest:(NSInteger)type withParameters:(NSDictionary*) parameters userInfo:(NSDictionary*)userInfo{
    [self _makeServerRequest:type withParameters:parameters userInfo:userInfo usingOperationQueue:NULL completion:NULL];
}

+(void) _makeServerRequest:(NSInteger)type withParameters:(NSDictionary*) parameters userInfo:(NSDictionary*)userInfo completion:(void(^)(NSArray*))completionBlock{
    [self _makeServerRequest:type withParameters:parameters userInfo:userInfo usingOperationQueue:NULL completion:completionBlock];
}
+(void) _makeServerRequest:(NSInteger)type withParameters:(NSDictionary*) parameters userInfo:(NSDictionary*)userInfo usingOperationQueue:(NSOperationQueue*)queue{
    [self _makeServerRequest:type withParameters:parameters userInfo:userInfo usingOperationQueue:queue completion:NULL];
}
+(void) _makeServerRequest:(NSInteger)type withParameters:(NSDictionary*) parameters userInfo:(NSDictionary*)userInfo usingOperationQueue:(NSOperationQueue*)queue completion:(void(^)(NSArray*))completionBlock{
    
    //All http connections must be done in the main thread
    
    if(! [NSThread isMainThread]){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _makeServerRequest:type withParameters:parameters userInfo:userInfo usingOperationQueue:queue completion:completionBlock];
        });
    }
    else{
        if([ZPReachability hasInternetConnection]){
            NSData* responseData = NULL;
            NSString* urlString;
            
            NSString* oauthkey =  [ZPPreferences OAuthKey];
            
            if(oauthkey!=NULL){
                
                NSInteger libraryID = LIBRARY_ID_NOT_SET;
                
                if(parameters != NULL){
                    libraryID = [[parameters objectForKey:ZPKEY_LIBRARY_ID] integerValue];
                }
                
                urlString = [self _baseURLWithLibraryID:libraryID];
                
                // Groups and collections
                if(type==ZPServerConnectionRequestPermissions){
                    urlString = [NSString stringWithFormat:@"%@keys/%@",urlString,oauthkey];
                }
                else if(type==ZPServerConnectionRequestGroups){
                    urlString = [NSString stringWithFormat:@"%@groups?key=%@&content=none",urlString,oauthkey];
                }
                else if (type==ZPServerConnectionRequestCollections){
                    urlString = [NSString stringWithFormat:@"%@collections?key=%@",urlString,oauthkey];
                }
                else if (type==ZPServerConnectionRequestSingleCollection){
                    urlString = [NSString stringWithFormat:@"%@collections/%@?key=%@",urlString,[parameters objectForKey:ZPKEY_COLLECTION_KEY],oauthkey];
                }
                
                // items
                
                else if (type==ZPServerConnectionRequestItems || type == ZPServerConnectionRequestTopLevelKeys){
                    NSString* collectionKey = [parameters objectForKey:ZPKEY_COLLECTION_KEY];
                    NSString* format =NULL;
                    if(type==ZPServerConnectionRequestItems){
                        format = @"atom";
                    }
                    else{
                        format = @"keys";
                    }
                    if(collectionKey!=NULL){
                        urlString = [NSString stringWithFormat:@"%@collections/%@/items?key=%@&format=%@",urlString,collectionKey,oauthkey,format];
                    }
                    else{
                        urlString = [NSString stringWithFormat:@"%@items/top?key=%@&format=%@",urlString,oauthkey,format];
                    }
                }
                else if (type==ZPServerConnectionRequestItemsAndChildren){
                    //            NSString* collectionKey = [parameters objectForKey:ZPKEY_COLLECTION_KEY];
                    //            NSAssert(collectionKey==NULL,@"Cannot request child items for collection");
                    urlString = [NSString stringWithFormat:@"%@items?key=%@&format=atom",urlString,oauthkey];
                }
                
                else if( type == ZPServerConnectionRequestSingleItem){
                    NSString* itemKey = [parameters objectForKey:ZPKEY_ITEM_KEY];
                    
                    urlString = [NSString stringWithFormat:@"%@items/%@?key=%@&format=atom",urlString,itemKey,oauthkey];
                }
                else if( type == ZPServerConnectionRequestSingleItemChildren){
                    NSString* itemKey = [parameters objectForKey:ZPKEY_ITEM_KEY];
                    
                    urlString = [NSString stringWithFormat:@"%@items/%@/children?key=%@&format=atom",urlString,itemKey,oauthkey];
                }
                else if( type == ZPServerConnectionRequestKeys){
                    urlString = [NSString stringWithFormat:@"%@items?key=%@&format=keys",urlString,oauthkey];
                }
                else if( type ==ZPServerConnectionRequestLastModifiedItem){
                    
                    NSString* collectionKey = [parameters objectForKey:ZPKEY_COLLECTION_KEY];
                    
                    if(collectionKey!=NULL){
                        urlString = [NSString stringWithFormat:@"%@collections/%@/items?key=%@&content=none&order=dateModified&sort=desc&start=0&limit=1",urlString,collectionKey,oauthkey];
                    }
                    else{
                        urlString = [NSString stringWithFormat:@"%@items/top?key=%@&content=none&order=dateModified&sort=desc&start=0&limit=1",urlString,oauthkey];
                    }
                    
                }
                if(parameters!=NULL){
                    for(id key in parameters){
                        if(! [ZPKEY_COLLECTION_KEY isEqualToString: key] &&
                           ! [ZPKEY_LIBRARY_ID isEqualToString: key] &&
                           ! ((type == ZPServerConnectionRequestSingleItemChildren || type == ZPServerConnectionRequestSingleItem) && [ZPKEY_ITEM_KEY isEqualToString:key])) {
                            urlString = [NSString stringWithFormat:@"%@&%@=%@",urlString,key,[[parameters objectForKey:key] stringByAddingPercentEscapesUsingEncoding:
                                                                                              NSUTF8StringEncoding]];
                            
                        }
                    }
                }
                                
                
                __weak ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:urlString]];
                request.tag = type;
                
                NSMutableDictionary* newUserInfo = [NSMutableDictionary dictionaryWithDictionary:userInfo];
                if(parameters != NULL) [newUserInfo setObject:parameters forKey:ZPKEY_PARAMETERS];
                request.userInfo = newUserInfo;

            
                [self _performRequest:request usingOperationQueue:queue completion:^(NSData* responseData){
                    
                    ZPServerResponseXMLParser* parserResponse;
                    
                    // This needs exception handling because sometimes we get garbage from the server
                    @try {
                        parserResponse = [self _parseXMLResponseData:responseData requestType:type];
                        [self _processParsedResponse:parserResponse requestType:type userInfo:newUserInfo];
                    }
                    @catch (NSException* exception) {
                        
                        NSString* description = [NSString stringWithFormat:@"Parsing response resulted in an exception. Type: %i \n%@\n\n%@\n%@\n%@\n\nResponse from server was:\n%@",
                                                 type, newUserInfo, exception.name, exception.reason, exception.callStackSymbols,
                                                 [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]];
                        DDLogError(description);
#ifdef ZPDEBUG
                        [NSException raise:exception.name format:@"%@",description];
#endif
                    }
                    
                    if(completionBlock != NULL){
                        completionBlock(parserResponse.parsedElements);
                    }

                }];
            
            
            }
            else{
                [(ZPAppDelegate*) [UIApplication sharedApplication].delegate startAuthenticationSequence];
            }
        }
    }
}

+(void) _performRequest:(ASIHTTPRequest*)request usingOperationQueue:(NSOperationQueue*)queue completion:(void(^)(NSData*))completionBlock{

    __weak ASIHTTPRequest* weakRequest = request;
    
    [request setCompletionBlock:^{
        
        // Succesful requests
        
        if(weakRequest.responseStatusCode >= 200 && weakRequest.responseStatusCode < 300){
            
            // Parsing the response takes time, so do this in the background

            NSData* data = weakRequest.responseData;
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0),^{completionBlock(data);});
        }
        
        else{
            DDLogError(@"Connection to Zotero server (%@) resulted in error %i. Full response: %@",
                       weakRequest.url, weakRequest.responseStatusCode,
                       [[NSString alloc] initWithData:weakRequest.responseData encoding:NSUTF8StringEncoding]);

            //If we receive a 403 (forbidden) error, delete the authorization key because we know that it is
            //no longer valid.
            
            if(weakRequest.responseStatusCode==403){
            
                DDLogError(@"The authorization key is no longer valid.");

                // Start a request for new keys
                [self _makeServerRequest:ZPServerConnectionRequestKeys withParameters:NULL userInfo:NULL];

                //Set ZotPad offline and ask the user what to do
                [ZPPreferences setOnline:FALSE];
                
                if(alertViewDelegate == NULL) alertViewDelegate = [[ZPAutenticationErrorAlertViewDelegate alloc] init];
                
                [[[UIAlertView alloc] initWithTitle:@"Authentication error"
                                            message:@"ZotPad is not authorized to access the library you are attempting to load and is now in offline mode. This can occur if your access key has been revoked or communications to Zotero server is blocked."
                                           delegate:alertViewDelegate cancelButtonTitle:@"Stay offline" otherButtonTitles:@"Check key", @"New key",nil] show];
            }
        }

        
    }];
    
    [request setFailedBlock:^{
        
        if(completionBlock != NULL){
            completionBlock(NULL);
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_SERVER_CONNECTION_FAILED
                                                            object:weakRequest
                                                          userInfo:weakRequest.userInfo];
        
        if([ZPPreferences online]){
            if(!weakRequest.isCancelled){
                DDLogError(@"Connection to Zotero server (%@) failed %@",weakRequest.url,weakRequest.error.localizedDescription);
                
                //TODO: Refactor these somewhere else
                
                //We need to notify that an empty item list is available so that the user interface knows to remove the busy overlay
                if(weakRequest.tag == ZPServerConnectionRequestTopLevelKeys){
                    [[NSNotificationCenter defaultCenter]
                     postNotificationName:ZPNOTIFICATION_ITEM_LIST_AVAILABLE
                     object:[NSArray array]
                     userInfo:weakRequest.userInfo];
                }
                //Break the item request into two smaller blocks as long as there are more than one item to retrieve and retry
                else if(weakRequest.tag == ZPServerConnectionRequestItemsAndChildren){
                    NSDictionary* params = (NSDictionary*)[weakRequest.userInfo objectForKey:ZPKEY_PARAMETERS];
                    NSString* keys = [params objectForKey:ZPKEY_ITEM_KEY];
                    NSInteger libraryID = [[params objectForKey:ZPKEY_LIBRARY_ID] integerValue];
                    NSArray* keyArray = [keys componentsSeparatedByString:@","];
                    if([keyArray count]>1){
                        
                        NSRange range;
                        
                        range.location=0;
                        range.length = [keyArray count]/2;
                        [self retrieveItemsFromLibrary:libraryID itemKeys:[keyArray subarrayWithRange:range]];
                        
                        range.location = range.length;
                        range.length= [keyArray count]-range.length;
                        [self retrieveItemsFromLibrary:libraryID itemKeys:[keyArray subarrayWithRange:range]];
                    }
                    
                }
            }
        }
    }];
    
    if(queue == NULL){
        //Requests must be started on the main tread
        [request performSelectorOnMainThread:@selector(startAsynchronous) withObject:nil waitUntilDone:NO];
    }
    else{
        [queue addOperation:request];
    }
    
}

+(ZPServerResponseXMLParser*) _parseXMLResponseData:(NSData*)responseData requestType:(NSInteger)type{
    
    
    ZPServerResponseXMLParser* parserDelegate = NULL;
    
    if(type == ZPServerConnectionRequestKeys || type == ZPServerConnectionRequestTopLevelKeys){
        //We do not use a parser for item keys because it is not XML. The itemkey format is kind of afterthough, so we will just parse it differentlys
        
        NSString* stringData = [[NSString alloc] initWithData:responseData
                                                     encoding:NSUTF8StringEncoding];
        parserDelegate = [[ZPServerResponseXMLParser alloc] init];
        NSMutableArray* itemKeys = [NSMutableArray arrayWithArray:[stringData componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        
        //It is possible that we get empty keys at the end
        while([[itemKeys lastObject] isEqualToString:@""]) [itemKeys removeLastObject];
        
        [parserDelegate setParsedElements:itemKeys];
    }
    //TODO refactor parsers to use the same superclass
    else if(type == ZPServerConnectionRequestPermissions){
        ZPServerResponseXMLParserKeyPermissions* keyParser = [[ZPServerResponseXMLParserKeyPermissions alloc] init];
        
        NSXMLParser* parser = [[NSXMLParser alloc] initWithData:responseData];
        [parser setDelegate:keyParser];
        [parser parse];
        
        parserDelegate = [[ZPServerResponseXMLParser alloc] init];
        [parserDelegate setParsedElements:[keyParser results]];
    }
    else{
        NSXMLParser* parser = [[NSXMLParser alloc] initWithData:responseData];
        
        //Choose the parser based on what we expect to receive
        
        if(type==ZPServerConnectionRequestGroups){
            parserDelegate =  [[ZPServerResponseXMLParserLibrary alloc] init];
        }
        else if (type==ZPServerConnectionRequestCollections || type == ZPServerConnectionRequestSingleCollection){
            parserDelegate =  [[ZPServerResponseXMLParserCollection alloc] init];
        }
        else if (type==ZPServerConnectionRequestItems || type == ZPServerConnectionRequestSingleItem || type== ZPServerConnectionRequestItemsAndChildren || type== ZPServerConnectionRequestSingleItemChildren || type == ZPServerConnectionRequestLastModifiedItem){
            parserDelegate =  [[ZPServerResponseXMLParserItem alloc] init];
        }
        
        [parser setDelegate: parserDelegate];
        [parser parse];
        
    }
    
    
    return parserDelegate;
    
}

+(void) _processParsedResponse:(ZPServerResponseXMLParser*)parserDelegate requestType:(NSInteger) type userInfo:(NSDictionary*) userInfo{
    
    
    NSDictionary* parameters = [userInfo objectForKey:ZPKEY_PARAMETERS];
    NSArray* parsedArray = [parserDelegate parsedElements];
    NSArray* allResults = [userInfo objectForKey:ZPKEY_ALL_RESULTS];
    
    if(allResults != NULL){
        allResults = [allResults arrayByAddingObjectsFromArray:parsedArray];
    }
    else{
        allResults = parsedArray;
    }
    
    if([allResults count] < parserDelegate.totalResults && type != ZPServerConnectionRequestLastModifiedItem){
        NSMutableDictionary* newUserInfo;
        NSMutableDictionary* newParams = [NSMutableDictionary dictionaryWithDictionary:parameters];
        if(userInfo == NULL){
            newUserInfo = [[NSMutableDictionary alloc] init];
        }
        else{
            newUserInfo = [NSMutableDictionary dictionaryWithDictionary: userInfo];
        }
        
        [newUserInfo setObject:allResults forKey:ZPKEY_ALL_RESULTS];
        [newParams setObject:[NSString stringWithFormat:@"%i",[allResults count]] forKey:@"start"];
        [self _makeServerRequest:type withParameters:newParams userInfo:newUserInfo];
    }
    
    //Process data
    
    else {
        switch(type){
                
            case ZPServerConnectionRequestPermissions:
                
                //Are group specifid permissions in use
            {
                if([allResults count] == 0){
                    
                    //Set ZotPad offline and ask the user what to do
                    [ZPPreferences setOnline:FALSE];
                    
                    if(alertViewDelegate == NULL) alertViewDelegate = [[ZPAutenticationErrorAlertViewDelegate alloc] init];
                    
                    [[[UIAlertView alloc] initWithTitle:@"Authorization error"
                                                message:@"ZotPad is not authorized to access any of your libraries on the Zotero server and is now in offline mode. This can occur if your access key has been revoked or communications to Zotero server is blocked."
                                               delegate:alertViewDelegate cancelButtonTitle:@"Stay offline" otherButtonTitles:@"Check key", @"New key",nil] show];
                    
                    
                }
                else{
                    
                    NSMutableArray* returnArray = [[NSMutableArray alloc] init];
                    
                    for(NSString* libraryString in allResults){
                        //All groups
                        if([libraryString isEqualToString:@"all"]){
                            
                            //enumerate through the permissions and build list of libraries
                            
                            NSArray* groups =[userInfo objectForKey:@"groups"];
                            
                            [returnArray addObjectsFromArray:groups];
                        }
                        //My library
                        //                        else if(libraryString isEqualToString:[NSString stringWithFormat:@"%i",LIBRARY_ID_MY_LIBRARY]]){
                        //                            [returnArray addObject:[ZPZoteroLibrary libraryWithID:LIBRARY_ID_MY_LIBRARY]];
                        //                        }
                        //Group
                        else{
                            [returnArray addObject:[ZPZoteroLibrary libraryWithID:[libraryString integerValue]]];
                        }
                    }
                    [ZPItemDataDownloadManager processNewLibrariesFromServer:returnArray];
                }
            }
                break;
                
            case ZPServerConnectionRequestGroups:
                
                [self _makeServerRequest:ZPServerConnectionRequestPermissions withParameters:NULL userInfo:[NSDictionary dictionaryWithObject:allResults forKey:@"groups"]];
                
                break;
                
            case ZPServerConnectionRequestCollections:
            case ZPServerConnectionRequestSingleCollection:
                [ZPItemDataDownloadManager processNewCollectionsFromServer:allResults forLibraryID:[[userInfo objectForKey:ZPKEY_LIBRARY_ID] integerValue]];
                break;
                
                
            case ZPServerConnectionRequestSingleItemChildren:
            {
                NSString* itemKey = [parameters objectForKey:ZPKEY_ITEM_KEY];
                ZPZoteroItem* item = [ZPZoteroItem itemWithKey:itemKey];
                
                NSMutableArray* notes= [[NSMutableArray alloc] initWithCapacity:[allResults count]];
                NSMutableArray* attachments = [[NSMutableArray alloc] initWithCapacity:[allResults count]];
                
                for(NSObject* child in allResults){
                    if([child isKindOfClass:[ZPZoteroAttachment class]]){
                        [attachments addObject:child];
                    }
                    else{
                        [notes addObject:child];
                    }
                }
                
                [attachments sortUsingDescriptors:[NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"title" ascending:TRUE]]];
                item.attachments = attachments;
                
                [notes sortUsingDescriptors:[NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"title" ascending:TRUE]]];
                item.notes = notes;
            }
                
            case ZPServerConnectionRequestItems:
            case ZPServerConnectionRequestItemsAndChildren:
            case ZPServerConnectionRequestSingleItem:
                
                [ZPItemDataDownloadManager processNewItemsFromServer:allResults forLibraryID:[[parameters objectForKey:ZPKEY_LIBRARY_ID] integerValue]];
                break;
                
            case ZPServerConnectionRequestLastModifiedItem:
                
                //If we have a limit=1, then we are interested in the time stamponly
                
                [ZPItemDataDownloadManager processNewTimeStampForLibrary:[[parameters objectForKey:ZPKEY_LIBRARY_ID] integerValue] collection:[parameters objectForKey:ZPKEY_COLLECTION_KEY] timestampValue:parserDelegate.updateTimestamp];
                
                break;
                //All keys for a library
            case ZPServerConnectionRequestKeys:
                [ZPItemDataDownloadManager processNewItemKeyListFromServer:allResults forLibraryID:[(NSNumber*)[parameters objectForKey:ZPKEY_LIBRARY_ID] integerValue]];
                break;
                
                //Keys for an item list
            case ZPServerConnectionRequestTopLevelKeys:
                if([@"1" isEqualToString:[parameters objectForKey:@"limit"]])
                    [ZPItemDataDownloadManager processNewTimeStampForLibrary:[[parameters objectForKey:ZPKEY_LIBRARY_ID] integerValue]
                                                                  collection:[parameters objectForKey:ZPKEY_COLLECTION_KEY]
                                                              timestampValue:parserDelegate.updateTimestamp];
                else
                    [ZPItemDataDownloadManager processNewTopLevelItemKeyListFromServer:allResults userInfo:userInfo];
                break;
        }
    }
}

+(NSString*) _tagsJSSONForDataObject:(ZPZoteroDataObject*) dataObject{
    
    NSMutableArray* tags= [[NSMutableArray alloc] initWithCapacity:dataObject.tags.count];
    
    for(NSString* tag in dataObject.tags){
        [tags addObject:[NSString stringWithFormat:@"{ \"tag\" : \"%@\" }",[self _JSONEscapeString:tag]]];
    }
    
    return [NSString stringWithFormat:@"[%@]",[tags componentsJoinedByString:@", "]];
}

+(NSString*) _JSONEscapeString:(NSString*) string{
    
    if(string == NULL) return @"";
    else return [[[string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"] stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""] stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
}


@end

