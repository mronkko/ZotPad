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


+(ZPServerResponseXMLParser*) _parseResponse:(ASIHTTPRequest*)request;
+(void) _processParsedResponse:(ZPServerResponseXMLParser*)parserResults forRequest:(ASIHTTPRequest*)request;

@end


@implementation ZPServerConnection

static ZPAutenticationErrorAlertViewDelegate* alertViewDelegate;
static NSOperationQueue* _addHocKeyRetrievals;

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
                
                if(libraryID== LIBRARY_ID_MY_LIBRARY || libraryID == LIBRARY_ID_NOT_SET){
                    urlString = [NSString stringWithFormat:@"https://api.zotero.org/users/%@/",[ZPPreferences userID]];
                }
                else{
                    urlString = [NSString stringWithFormat:@"https://api.zotero.org/groups/%i/",libraryID];
                }
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
                
                //Identifiers
                if([ZPPreferences addIdentifiersToAPIRequests]){
                    
                    char data[16];
                    for (int x=0;x<16;data[x++] = (char)('A' + (arc4random_uniform(26))));
                    NSString* t = [[NSString alloc] initWithBytes:data length:16 encoding:NSUTF8StringEncoding];
                    
                    if(type==ZPServerConnectionRequestPermissions){
                        urlString = [urlString stringByAppendingFormat:@"?t=%@",t];
                    }
                    else{
                        urlString = [urlString stringByAppendingFormat:@"&t=%@",t];
                        
                    }
                    
                    //Device identifiers are available again in iOS 6.
                    if([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0){
                        urlString = [urlString stringByAppendingFormat:@"&d=%@",[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
                    }
                }
                DDLogVerbose(@"Staring request %@",urlString);
                
                //TODO: Document why this needs to be weak. (Check the compiler warnign that comes from disabling this)
                
                __weak ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:urlString]];
                request.tag = type;
                
                NSMutableDictionary* newUserInfo = [NSMutableDictionary dictionaryWithDictionary:userInfo];
                if(parameters != NULL) [newUserInfo setObject:parameters forKey:ZPKEY_PARAMETERS];
                request.userInfo = newUserInfo;
                
                [request setCompletionBlock:^{
                    //If we receive a 403 (forbidden) error, delete the authorization key because we know that it is
                    //no longer valid.
                    
                    DDLogVerbose(@"Request to %@ returned status code %i",request.url,request.responseStatusCode);
                    if(request.responseStatusCode==403){
                      
                        if(completionBlock != NULL){
                            completionBlock(NULL);
                        }

                        DDLogError(@"Connection to Zotero server (%@) resulted in error %i. Full response: %@",urlString,request.responseStatusCode,[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
                        
                        
                        if(request.tag == ZPServerConnectionRequestKeys){
                            
                            NSArray* librariesThatCanBeAccessed = [[self _parseResponse:request] parsedElements];
                            
                            if(librariesThatCanBeAccessed == NULL || [librariesThatCanBeAccessed count]==0){
                                DDLogError(@"The authorization key is no longer valid.");
                                
                                //Set ZotPad offline and ask the user what to do
                                [ZPPreferences setOnline:FALSE];
                                
                                if(alertViewDelegate == NULL) alertViewDelegate = [[ZPAutenticationErrorAlertViewDelegate alloc] init];
                                
                                [[[UIAlertView alloc] initWithTitle:@"Authentication error"
                                                            message:@"ZotPad is not authorized to access any of your libraries on the Zotero server and is now in offline mode. This can occur if your access key has been revoked or communications to Zotero server is blocked."
                                                           delegate:alertViewDelegate cancelButtonTitle:@"Stay offline" otherButtonTitles:@"Check key", @"New key",nil] show];
                            }
                            else {
                                [[[UIAlertView alloc] initWithTitle:@"Authorization error"
                                                            message:@"ZotPad is not authorized to access the library you are attempting to load. This can occur if the privileges of your access key have been changed, but ZotPad cache has not yet been updated to reflect these changes."
                                                           delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:nil] show];
                            }
                            
                        }
                        else{
                            [self _makeServerRequest:ZPServerConnectionRequestKeys withParameters:NULL userInfo:NULL];
                        }
                    }
                    else if(request.responseStatusCode == 200){
                        
                        // Parsing the response takes time, so do this in the background
                        ASIHTTPRequest* retainedRequest = request;
                        void (^responseProcessingBlock)() = ^{
                            ZPServerResponseXMLParser* parserResponse = [self _parseResponse:retainedRequest];
                            [self _processParsedResponse:parserResponse forRequest:retainedRequest];

                            if(completionBlock != NULL){
                                completionBlock(parserResponse.parsedElements);
                            }

                        };
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0),responseProcessingBlock);
                    }
                    else{
                        DDLogError(@"Connection to Zotero server (%@) resulted in error %i. Full response: %@",urlString,request.responseStatusCode,[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
                        if(completionBlock != NULL){
                            completionBlock(NULL);
                        }
                    }
                    
                }];
                [request setFailedBlock:^{

                    if(completionBlock != NULL){
                        completionBlock(NULL);
                    }
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_SERVER_CONNECTION_FAILED
                                                                        object:request
                                                                      userInfo:request.userInfo];
                    
                    if([ZPPreferences online]){
                        if(!request.isCancelled){
                            DDLogError(@"Connection to Zotero server (%@) failed %@",urlString,request.error.localizedDescription);
                            
                            //We need to notify that an empty item list is available so that the user interface knows to remove the busy overlay
                            if(request.tag == ZPServerConnectionRequestTopLevelKeys){
                                [[NSNotificationCenter defaultCenter]
                                 postNotificationName:ZPNOTIFICATION_ITEM_LIST_AVAILABLE
                                 object:[NSArray array]
                                 userInfo:request.userInfo];
                            }
                            //Break the item request into two smaller blocks as long as there are more than one item to retrieve and retry
                            else if(request.tag == ZPServerConnectionRequestItems){
                                NSDictionary* params = (NSDictionary*)[request.userInfo objectForKey:ZPKEY_PARAMETERS];
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
                    [request startAsynchronous];
                }
                else{
                    [queue addOperation:request];
                }
            }
            else{
                if(completionBlock != NULL){
                    completionBlock(NULL);
                }
                [(ZPAppDelegate*) [UIApplication sharedApplication].delegate startAuthenticationSequence];
            }
        }
    }
}

+(ZPServerResponseXMLParser*) _parseResponse:(ASIHTTPRequest*)request{

    NSData* responseData = request.responseData;
    NSInteger type = request.tag;
    
    

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
        
        /*
         #ifdef ZPDEBUG
         NSString* responseString = [[NSString alloc] initWithData:responseData  encoding:NSUTF8StringEncoding];
         parserDelegate.fullResponse = responseString;
         //Check that we got time stamps for all objects
         for(ZPZoteroDataObject* dataObject in parserDelegate.parsedElements){
         dataObject.responseDataFromWhichThisItemWasCreated = responseString;
         if(dataObject.serverTimestamp == NULL){
         [NSException raise:@"Missing timestamp from Zotero server" format:@"Object with key %@ has a missing timestamp. Dump of full response %@",dataObject.key,[[NSString alloc] initWithData:responseData  encoding:NSUTF8StringEncoding]];
         }
         }
         #endif
         */
    }
    
    /*
     //Iy is OK to get 1/0 here because queries that return a single results do not have totalResults
     DDLogVerbose(@"Request returned %i/%i results: %@ Active queries: %i",[[parserDelegate parsedElements] count],[parserDelegate totalResults], urlString,_activeRequestCount);
     
     //If there are no results, dump the entire response so that we see what the problem was
     if([[parserDelegate parsedElements] count] == 0){
     DDLogVerbose(@"%@",[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
     }
     */
    
    return parserDelegate;

}

+(void) _processParsedResponse:(ZPServerResponseXMLParser*)parserDelegate forRequest:(ASIHTTPRequest*)request{
    

    NSDictionary* userInfo = request.userInfo;
    NSDictionary* parameters = [userInfo objectForKey:ZPKEY_PARAMETERS];
    NSArray* parsedArray = [parserDelegate parsedElements];
    NSArray* allResults = [userInfo objectForKey:ZPKEY_ALL_RESULTS];
    NSInteger tag = request.tag;
 
    if(allResults != NULL){
        allResults = [allResults arrayByAddingObjectsFromArray:parsedArray];
    }
    else{
        allResults = parsedArray;
    }
    
    if([allResults count] < parserDelegate.totalResults && tag != ZPServerConnectionRequestLastModifiedItem){
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
        [self _makeServerRequest:tag withParameters:newParams userInfo:newUserInfo];
    }
    
    //Process data
    
    else {
        switch(request.tag){
                
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
                            
                            NSArray* groups =[request.userInfo objectForKey:@"groups"];
                            
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






@end

