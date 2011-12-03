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
#import "ZPAuthenticationProcess.h"

//Private methods

@interface ZPServerConnection();
    

-(ZPServerResponseXMLParser*) makeServerRequest:(NSInteger)type withLibrary:(NSInteger)libraryID withCollection:(NSString*)collection withParameters:(NSDictionary*) parameters;

@end


@implementation ZPServerConnection

static ZPServerConnection* _instance = nil;

const NSInteger ZPServerConnectionRequestGroups = 1;
const NSInteger ZPServerConnectionRequestCollections = 2;
const NSInteger ZPServerConnectionRequestItems = 3;


-(id)init
{
    self = [super init];
    
    //Load the key from preferences
    
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

-(ZPServerResponseXMLParser*) makeServerRequest:(NSInteger)type withLibrary:(NSInteger)libraryID withCollection:(NSString*)collectionKey withParameters:(NSDictionary*) parameters{
    
    
    NSData* responseData = NULL;
    NSString* urlString;
   
    NSString* oauthkey =  [[NSUserDefaults standardUserDefaults] objectForKey:@"OAuthKey"];
    if(oauthkey!=NULL){

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
        else if (type==ZPServerConnectionRequestItems){
            
            if(collectionKey!=NULL){
                urlString = [NSString stringWithFormat:@"%@collections/%@/items?key=%@&format=atom",urlString,collectionKey,oauthkey];
            }
            else{
                urlString = [NSString stringWithFormat:@"%@items/top?key=%@&format=atom",urlString,oauthkey];
            }
        }
        
        if(parameters!=NULL){
            for(id key in parameters){
                urlString = [NSString stringWithFormat:@"%@&%@=%@",urlString,key,[parameters objectForKey:key]];
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

        ZPServerResponseXMLParser* parserDelegate =  [[ZPServerResponseXMLParser alloc] init];
    
        [parser setDelegate: parserDelegate];
        [parser parse];

        if(_debugServerConnection){
            NSLog(@"Request returned %i/%i results: %@ Active queries: %i",[[parserDelegate parsedElements] count],[parserDelegate totalResults], urlString,_activeRequestCount);            
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


-(NSArray*) retrieveLibrariesFromServer{
        
    //Retrieve all libraries from the server
    

    ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestGroups withLibrary:0 withCollection:NULL withParameters:NULL];

    NSArray* returnArray = [parserDelegate parsedElements];
 
    if(parserDelegate == NULL) return NULL;
    
    //If there is more data coming, retrieve it
    while([returnArray count] < parserDelegate.totalResults){

        NSMutableDictionary* parameters=[[NSMutableDictionary alloc] initWithCapacity:1];
        [parameters setObject:[NSString stringWithFormat:@"%i",[returnArray count]] forKey:@"start"];

        ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestGroups withLibrary:0 withCollection:NULL withParameters:parameters];

        if(parserDelegate == NULL) return NULL;
        
        NSArray* returnArray = [parserDelegate parsedElements];

        returnArray=[returnArray arrayByAddingObjectsFromArray:parserDelegate.parsedElements];
    }
    
    
    return returnArray;
    
}

-(NSArray*) retrieveCollectionsForLibraryFromServer:(NSInteger)libraryID{
    
    
    ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestCollections withLibrary:libraryID withCollection:NULL withParameters:NULL];
    if(parserDelegate == NULL) return NULL;

    NSArray* returnArray = [parserDelegate parsedElements];
    
    //If there is more data coming, retrieve it
    while([returnArray count] < parserDelegate.totalResults){
        
        NSMutableDictionary* parameters=[[NSMutableDictionary alloc] initWithCapacity:1];
        [parameters setObject:[NSString stringWithFormat:@"%i",[returnArray count]] forKey:@"start"];
        
        ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestCollections withLibrary:libraryID withCollection:NULL withParameters:parameters];
        if(parserDelegate == NULL) return NULL;
        
        NSArray* returnArray = [parserDelegate parsedElements];
        
        returnArray=[returnArray arrayByAddingObjectsFromArray:parserDelegate.parsedElements];
    }
        
    return returnArray;
}



/*

Retrieves items from server and stores these in the database. Returns and array of NSStrings that contain the item keys
   
*/

-(ZPServerResponseXMLParser*) retrieveItemsFromLibrary:(NSInteger)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString sortField:(NSString*)sortField sortDescending:(BOOL)sortIsDescending limit:(NSInteger)limit start:(NSInteger)start{
    
   
    
    NSMutableDictionary* parameters=[[NSMutableDictionary alloc] initWithCapacity:10];
    
    [parameters setObject:@"bib" forKey:@"content"];
    [parameters setObject:@"apa" forKey:@"style"];

    //Search
    if(searchString!=NULL && ! [searchString isEqualToString:@""]){
        [parameters setObject:[searchString stringByAddingPercentEscapesUsingEncoding:
                               NSASCIIStringEncoding] forKey:@"q"];
    }
    //Sort
    if(sortField!=NULL){
        [parameters setObject:sortField forKey:@"sort"];

        if(sortIsDescending){
            [parameters setObject:@"desc" forKey:@"order"];
        }
        else{
            [parameters setObject:@"asc" forKey:@"order"];
        }
    }
    if(start!=0){
        [parameters setObject:[NSString  stringWithFormat:@"%i",start] forKey:@"start"];
    }
    if(limit!=0){
        [parameters setObject:[NSString  stringWithFormat:@"%i",limit] forKey:@"limit"];
    }
    
    ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestItems withLibrary:libraryID withCollection:collectionKey withParameters:parameters];
    
    return parserDelegate;
    
}



@end
