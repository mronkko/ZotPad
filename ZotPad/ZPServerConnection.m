//
//  ZPServerConnection.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPAppDelegate.h"
#import "ZPServerConnection.h"
#import "OAuthConsumer.h"
#import "OAToken.h"
#import "ZPAuthenticationDialog.h"
#import "ZPServerResponseXMLParser.h"

@implementation ZPServerConnection

static ZPServerConnection* _instance = nil;

-(id)init
{
    self = [super init];
    
    //Load the key from preferences
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    self->_oauthkey = [defaults objectForKey:@"OAuthKey"];
	self->_userID = [defaults objectForKey:@"userID"];
    self->_username = [defaults objectForKey:@"username"];
    
    self->_itemRetrieveQueue = [[NSOperationQueue alloc] init];
    
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
    
    return(self->_oauthkey != nil);
    
}

// Client Key	4cb573ead72e5d84eab4
// Client Secret	605a2a699d22dc4cce7f
// Temporary Credential Request: https://www.zotero.org/oauth/request
// Token Request URI: https://www.zotero.org/oauth/access
// Resource Owner Authorization URI: https://www.zotero.org/oauth/authorize


- (void) doAuthenticate:(UIViewController*) source{

    self->_sourceViewController = source;
    [self makeOAuthRequest: NULL];
    
}

- (void) makeOAuthRequest:(OAToken *) token {
    OAConsumer *consumer = [[OAConsumer alloc] initWithKey:@"4cb573ead72e5d84eab4"
                                                    secret:@"605a2a699d22dc4cce7f"];
    
    NSURL *url;
    
    if(token==nil){
        url= [NSURL URLWithString:@"https://www.zotero.org/oauth/request"];
    }
    else{
        url= [NSURL URLWithString:@"https://www.zotero.org/oauth/access"];        
    }
    OAMutableURLRequest *request = [[OAMutableURLRequest alloc] initWithURL:url
                                                                   consumer:consumer
                                                                      token:token   // we don't have a Token yet
                                                                      realm:nil   // our service provider doesn't specify a realm
                                                          signatureProvider:nil]; // use the default method, HMAC-SHA1
    
    [request setHTTPMethod:@"POST"];
    
    OADataFetcher *fetcher = [[OADataFetcher alloc] init];
    
    if(token==nil){
        [fetcher fetchDataWithRequest:request
                         delegate:self
                didFinishSelector:@selector(requestTokenTicket:didFinishWithData:)
     
                  didFailSelector:@selector(requestTokenTicket:didFailWithError:)];
    }
    else{
            [fetcher fetchDataWithRequest:request
                                 delegate:self
                        didFinishSelector:@selector(requestAccessToken:didFinishWithData:)
             
                          didFailSelector:@selector(requestAccessToken:didFailWithError:)];
        }

}

- (void)requestTokenTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data {
    if (ticket.didSucceed) {
        NSString *responseBody = [[NSString alloc] initWithData:data
                                                       encoding:NSUTF8StringEncoding];
        OAToken* requestToken = [[OAToken alloc] initWithHTTPResponseBody:responseBody];
        
        
        NSLog(@"Starting authentication process");
        self->_authenticationDialog = [[ZPAuthenticationDialog alloc] initWithNibName:@"Authenticate" bundle:nil];
        [ self->_authenticationDialog setToken : requestToken];
        [self->_sourceViewController presentModalViewController: self->_authenticationDialog animated:YES];

    }
    
}

- (void)requestAccessToken:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data {
    if (ticket.didSucceed) {
        NSString *responseBody = [[NSString alloc] initWithData:data
                                                       encoding:NSUTF8StringEncoding];
        OAToken* requestToken = [[OAToken alloc] initWithHTTPResponseBody:responseBody];
        
        
        NSLog(@"Got access token");
        
        //Save the key to preferences
        [[NSUserDefaults standardUserDefaults] setValue:[requestToken key] forKey:@"OAuthKey"];
        self->_oauthkey = [requestToken key];
        
        //Save userID and username
        NSArray* parts = [responseBody componentsSeparatedByString:@"&"];
        
        NSString* userID = [[[parts objectAtIndex:2]componentsSeparatedByString:@"="] objectAtIndex:1];
        [[NSUserDefaults standardUserDefaults] setValue:userID forKey:@"userID"];
        self->_userID = userID;
        
        NSString* username = [[[parts objectAtIndex:3]componentsSeparatedByString:@"="] objectAtIndex:1];
        [[NSUserDefaults standardUserDefaults] setValue:username forKey:@"username"];
        self->_username = username;
        
        //Force update from server
//TODO:        [(UITableViewController*) self->_sourceViewController reloadData];
        
        //Dismiss the modal dialog
        [ self->_authenticationDialog dismissModalViewControllerAnimated:YES];

      
        
    }
    
}

- (void)requestTokenTicket:(OAServiceTicket *)ticket didFailWithError:(NSError *)error {
    NSLog(@"Error");
}
- (void)requestAccessToken:(OAServiceTicket *)ticket didFailWithError:(NSError *)error {
    NSLog(@"Error");
}


-(NSArray*) retrieveLibrariesFromServer{
        
    //Retrieve all libraries from the server
    
    NSURL *fileURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.zotero.org/users/%@/groups?key=%@",_userID,_oauthkey]];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:fileURL];

    ZPServerResponseXMLParser* parserDelegate =  [[ZPServerResponseXMLParser alloc] init];
    
    [parser setDelegate: parserDelegate];
    [parser parse];
    
    return [parserDelegate results];
    
}

-(NSArray*) retrieveCollectionsForLibraryFromServer:(NSInteger)libraryID{
    
    NSURL *fileURL;
    
    if(libraryID==0){
        fileURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.zotero.org/users/%@/collections?key=%@",_userID,_oauthkey]];
    }
    else{
        fileURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.zotero.org/groups/%i/collections?key=%@",libraryID,_oauthkey]];        
    }
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:fileURL];
    
    ZPServerResponseXMLParser* parserDelegate =  [[ZPServerResponseXMLParser alloc] init];
    
    [parser setDelegate: parserDelegate];
    [parser parse];
    
    return [parserDelegate results];
}


-(NSArray*) retrieveItemsFromLibrary:(NSInteger)libraryID collection:(NSString)collectionKey searchString:(NSString*)searchString sortField:(NSString*)sortField sortDescending:(BOOL)sortIsDescending{
    
    //We know that a view has changed, so we can cancel all existing item retrieving
    
    [self->_itemRetrieveQueue cancelAllOperations];
    
    NSArray* returnArray = [self _retrieveItemsFromLibrary:libraryID collection:collectionKey searchString:searchString sortField:sortField sortDescending:sortIsDescending maxCount:15 offset:0];
    
    
    //Set up a background operation to retrieve rest of the items in the view
    
    
    

}

/*
    Retrieves items from server and stores these in the database. Returns and array of NSStrings that contain the item keys
*/

-(NSArray*) _retrieveItemsFromLibrary:(NSInteger)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString sortField:(NSString*)sortField sortDescending:(BOOL)sortIsDescending maxCount:(NSInteger)maxCount offset:(NSInteger)offest{
    
    //We know that a view has changed, so we can cancel all existing item retrieving
    
    [self->_itemRetrieveQueue cancelAllOperations];
    
    NSString* urlString = @"https://api.zotero.org/";
    NSURL* fileURL =[NSURL URLWithString:urlString];
    
    if(libraryID==0){
        urlString = [NSString stringWithFormat:@"%@users/%@/",urlString,_userID];
    }
    else{
        urlString = [NSString stringWithFormat:@"%@groups/%i/",urlString,libraryID];
    }
    
    if(collectionKey!=NULL){
        urlString = [NSString stringWithFormat:@"%@collections/%@/items",urlString,collectionKey];
    }
    else{
        urlString = [NSString stringWithFormat:@"%@top",urlString];
    }
    
    urlString = [NSString stringWithFormat:@"?key=%@",urlString,_oauthkey];
    
    //Search
    if(searchString!=NULL & ! [[searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]){
        urlString = [NSString stringWithFormat:@"&q=%@",urlString,searchString];
    }
    //Sort
    if(sortField!=NULL){
        NSString* sortDirString;
        if(sortIsDescending){
            sortDirString=@"desc";
        }
        else{
            sortDirString=@"asc";
        }
        
        [NSString stringWithFormat:@"&order=%@&sort=%@",urlString,sortField,sortDirString];
    }
    
    fileURL = [NSURL URLWithString:urlString];        
    
    
    //TODO: Continue from here
    
}

@end
