//
//  ZPServerConnection.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

//TODO: Implement webdav client http://code.google.com/p/wtclient/


#import "ZPAppDelegate.h"
#import "ZPServerConnection.h"
#import "ZPAuthenticationDialog.h"
#import "ZPServerResponseXMLParser.h"
#import "ZPServerResponseXMLParserItem.h"
#import "ZPServerResponseXMLParserLibrary.h"
#import "ZPServerResponseXMLParserCollection.h"
#import "ZPAuthenticationProcess.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroCollection.h"

//Private methods

@interface ZPServerConnection();
    

-(ZPServerResponseXMLParser*) makeServerRequest:(NSInteger)type withParameters:(NSDictionary*) parameters;

@end


@implementation ZPServerConnection

static ZPServerConnection* _instance = nil;

const NSInteger ZPServerConnectionRequestGroups = 1;
const NSInteger ZPServerConnectionRequestCollections = 2;
const NSInteger ZPServerConnectionRequestSingleCollection = 3;
const NSInteger ZPServerConnectionRequestItems = 4;
const NSInteger ZPServerConnectionRequestItemsDetails = 5;
const NSInteger ZPServerConnectionRequestSingleItemDetails = 6;


-(id)init
{
    self = [super init];
        
    _activeRequestCount = 0;
    _debugServerConnection = TRUE;
    
    return self;
}

/*

 Singleton accessor
 */

+(ZPServerConnection*) instance {
    if(_instance == NULL){
        _instance = [[ZPServerConnection alloc] init];
    }
    return _instance;
}

/*
 We assume that the client is authenticated if a oauth key exists. The key will be cleared if we notice that it is not valid while using it.
 */

- (BOOL) authenticated{
    
    return([[NSUserDefaults standardUserDefaults] objectForKey:@""] != nil);
    
}

/*

 This will get the localized item types
 https://api.zotero.org/itemTypes

 This will get the localized fields for item type
 https://api.zotero.org/itemFields?itemType=book
 
 This will get a list of valid creator types
 https://api.zotero.org/itemTypeCreatorTypes?itemType=book
 
 This will get a template for a new item
 https://api.zotero.org/items/new?itemType=book
 
*/


-(ZPServerResponseXMLParser*) makeServerRequest:(NSInteger)type withParameters:(NSDictionary*) parameters{
    
    
    NSData* responseData = NULL;
    NSString* urlString;
   
    NSString* oauthkey =  [[NSUserDefaults standardUserDefaults] objectForKey:@"OAuthKey"];
    if(oauthkey!=NULL){

        NSInteger libraryID = [(NSNumber*)[parameters objectForKey:@"libraryID"] integerValue];
        
        if(libraryID==1 || libraryID == 0){
            urlString = [NSString stringWithFormat:@"https://api.zotero.org/users/%@/",[[NSUserDefaults standardUserDefaults] objectForKey:@"userID"]];
        }
        else{
            urlString = [NSString stringWithFormat:@"https://api.zotero.org/groups/%i/",libraryID];        
        }
        
        
        if(type==ZPServerConnectionRequestGroups){
            urlString = [NSString stringWithFormat:@"%@groups?key=%@&content=none",urlString,oauthkey];
        }
        else if (type==ZPServerConnectionRequestCollections){
            urlString = [NSString stringWithFormat:@"%@collections?key=%@",urlString,oauthkey];
        }
        else if (type==ZPServerConnectionRequestSingleCollection){
            urlString = [NSString stringWithFormat:@"%@collections/%@?key=%@",urlString,[parameters objectForKey:@"collectionKey"],oauthkey];
        }

        else if (type==ZPServerConnectionRequestItems){
            NSString* collectionKey = [parameters objectForKey:@"collectionKey"];

            if(collectionKey!=NULL){
                urlString = [NSString stringWithFormat:@"%@collections/%@/items?key=%@&format=atom",urlString,collectionKey,oauthkey];
            }
            else{
                urlString = [NSString stringWithFormat:@"%@items/top?key=%@&format=atom",urlString,oauthkey];
            }
        }
        else if( type == ZPServerConnectionRequestSingleItemDetails){
             NSString* itemKey = [parameters objectForKey:@"itemKey"];

            urlString = [NSString stringWithFormat:@"%@items/%@?key=%@&format=atom",urlString,itemKey,oauthkey];
        }
                
        if(parameters!=NULL){
            for(id key in parameters){
                if(! [@"itemKey" isEqualToString: key] &&
                   ! [@"collectionKey" isEqualToString: key] &&
                   ! [@"libraryID" isEqualToString: key]) {
                    urlString = [NSString stringWithFormat:@"%@&%@=%@",urlString,key,[parameters objectForKey:key]];
                
                }
            }
        }
        
        
        _activeRequestCount++;

        if(_debugServerConnection){
            NSLog(@"Request started: %@ Active queries: %i",urlString,_activeRequestCount);
        }

        
        //First request starts the network indicator
        if(_activeRequestCount==1) [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        
        NSURLRequest * urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSURLResponse * response = nil;
        NSError* error = nil;
        responseData= [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
        
        //If we receive a 403 (forbidden) error, delete the authorization key because we know that it is
        //no longer valid.
        if([(NSHTTPURLResponse*)response statusCode]==403){
            NSLog(@"The authorization key is no longer valid.");
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"OAuthKey"];
        }
       
        _activeRequestCount--;


        if(_debugServerConnection && responseData==NULL){
            NSLog(@"Request returned no results: %@ Active queries: %i",urlString,_activeRequestCount);            
        }
        //Last request hides the network indicator
        if(_activeRequestCount==0) [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    }

    if(responseData!=NULL){
        NSXMLParser* parser = [[NSXMLParser alloc] initWithData:responseData];

        ZPServerResponseXMLParser* parserDelegate;
        //Choose the parser based on what we expect to receive
        
        if(type==ZPServerConnectionRequestGroups){
            parserDelegate =  [[ZPServerResponseXMLParserLibrary alloc] init];    
        }
        else if (type==ZPServerConnectionRequestCollections || type == ZPServerConnectionRequestSingleCollection){
            parserDelegate =  [[ZPServerResponseXMLParserCollection alloc] init];    
        }
        else if (type==ZPServerConnectionRequestItems || type == ZPServerConnectionRequestSingleItemDetails){
            parserDelegate =  [[ZPServerResponseXMLParserItem alloc] init];    
        }
        
//       if(_debugServerConnection)  NSLog(@"%@",[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
    
        [parser setDelegate: parserDelegate];
        [parser parse];

        if(_debugServerConnection){
            //Iy is OK to get 1/0 here because queries that return a single results do not have totalResults
            NSLog(@"Request returned %i/%i results: %@ Active queries: %i",[[parserDelegate parsedElements] count],[parserDelegate totalResults], urlString,_activeRequestCount);            
            
            //If there are no results, dump the entire response so that we see what the problem was
            if([[parserDelegate parsedElements] count] == 0){
                NSLog(@"%@",[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
            }
        }


        return parserDelegate;
    }
    else{
        if(oauthkey==NULL){

            //Initialize a new authentication process if there is currently not an ongoing one
            if(![[ZPAuthenticationProcess instance] isActive]){
                [[ZPAuthenticationProcess instance] startAuthentication];
            }
        }
        return NULL;
    }
}

-(ZPZoteroItem*) retrieveSingleItemDetailsFromServer:(ZPZoteroItem*)item{

    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:item.libraryID ] forKey:@"libraryID"];
    [parameters setObject:item.key forKey:@"itemKey"];
    [parameters setObject:@"json" forKey:@"content"];
    
    ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestSingleItemDetails withParameters:parameters];
    
    NSArray* parsedArray = [parserDelegate parsedElements];
    
    if(parserDelegate == NULL || [parsedArray count] == 0 ) return NULL;
    
    return [parsedArray objectAtIndex:0];   
}

-(NSArray*) retrieveLibrariesFromServer{
        
    //Retrieve all libraries from the server
    

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
    
    
    return returnArray;
    
}

-(NSArray*) retrieveCollectionsForLibraryFromServer:(NSNumber*)libraryID{
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:libraryID forKey:@"libraryID"];

    ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestCollections withParameters:parameters];
    if(parserDelegate == NULL) return NULL;

    NSArray* returnArray = [parserDelegate parsedElements];
    
    //If there is more data coming, retrieve it
    while([returnArray count] < parserDelegate.totalResults){
        
        [parameters setObject:[NSString stringWithFormat:@"%i",[returnArray count]] forKey:@"start"];
        
        ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestCollections withParameters:parameters];
        if(parserDelegate == NULL) return NULL;
        
        returnArray=[returnArray arrayByAddingObjectsFromArray:parserDelegate.parsedElements];
    }
        
    return returnArray;
}

-(ZPZoteroCollection*) retrieveCollection:(NSString*)collectionKey fromLibrary:(NSNumber*)libraryID{

    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:libraryID forKey:@"libraryID"];
    [parameters setValue:collectionKey forKey:@"collectionKey"];
    
    ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestCollections withParameters:parameters];
    if(parserDelegate == NULL) return NULL;
    
    return [[parserDelegate parsedElements] objectAtIndex:0];

}


/*

Retrieves items from server and stores these in the database. Returns and array of NSStrings that contain the item keys
   
*/

-(ZPServerResponseXMLParser*) retrieveItemsFromLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortIsDescending limit:(NSInteger)limit start:(NSInteger)start{
    
   
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:libraryID  forKey:@"libraryID"];

    if(collectionKey!=NULL) [parameters setObject:collectionKey forKey:@"collectionKey"];
    
    [parameters setObject:@"bib" forKey:@"content"];
    [parameters setObject:@"apa" forKey:@"style"];

    //Search
    if(searchString!=NULL && ! [searchString isEqualToString:@""]){
        [parameters setObject:[searchString stringByAddingPercentEscapesUsingEncoding:
                               NSASCIIStringEncoding] forKey:@"q"];
    }
    //Sort
    if(orderField!=NULL){
        [parameters setObject:orderField forKey:@"order"];

        if(sortIsDescending){
            [parameters setObject:@"desc" forKey:@"sort"];
        }
        else{
            [parameters setObject:@"asc" forKey:@"sort"];
        }
    }
    if(start!=0){
        [parameters setObject:[NSString  stringWithFormat:@"%i",start] forKey:@"start"];
    }
    if(limit!=0){
        [parameters setObject:[NSString  stringWithFormat:@"%i",limit] forKey:@"limit"];
    }
    
    ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestItems withParameters:parameters];
    
    return parserDelegate;
    
}



@end
