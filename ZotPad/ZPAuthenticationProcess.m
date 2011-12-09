//
//  ZPAuthenticationProcess.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/1/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPAuthenticationProcess.h"
#import "ZPAuthenticationDialog.h"
#import "ZPDataLayer.h"
#import "ZPServerConnection.h"
#import "ZPMasterViewController.h"

@implementation ZPAuthenticationProcess


static ZPAuthenticationProcess* _instance = nil;

+(ZPAuthenticationProcess*) instance {
    if(_instance == NULL){
        _instance = [[ZPAuthenticationProcess alloc] init];
    }
    return _instance;
}

-(id) init{
    self=[super init];
    _isActive = FALSE;
    return self;
}

-(void) startAuthentication{
    
    
    NSLog(@"Starting authentication process");
    _isActive = TRUE;

    //If the UI is not yet visible, wait for it to become visible before proceeding.
        
    UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;        

    while(!root.view.window){
        sleep(.1);
    }    
    
    [self performSelectorOnMainThread:@selector(showAuthenticationSeque) withObject:nil waitUntilDone:NO];

}

-(void)showAuthenticationSeque{

    [self makeOAuthRequest: NULL];

    UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;        
    [root performSegueWithIdentifier:@"AuthenticationSeque" sender:root];    
}
-(BOOL) isActive{
    return _isActive;
}

-(void) processVerifier:(NSString*)verifier{
    [_latestToken setValue:verifier forKey:@"verifier"];
    [self makeOAuthRequest:_latestToken];
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
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
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

/*
 This is the first part of the authentication to retrieve a temporary token
 */
- (void)requestTokenTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data {
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    if (ticket.didSucceed) {
        NSString *responseBody = [[NSString alloc] initWithData:data
                                                       encoding:NSUTF8StringEncoding];
        
        _latestToken = [[OAToken alloc] initWithHTTPResponseBody:responseBody];
        
        [[ZPAuthenticationDialog instance] setKeyAndLoadZoteroSite:[_latestToken key]];
    }
    
}

/*
 This is the second part where we get the permanent token
 */

- (void)requestAccessToken:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data {
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    if (ticket.didSucceed) {
        NSString *responseBody = [[NSString alloc] initWithData:data
                                                       encoding:NSUTF8StringEncoding];
        _latestToken = [[OAToken alloc] initWithHTTPResponseBody:responseBody];
        
        
        NSLog(@"Got access token");
        
        //Save the key to preferences
        [[NSUserDefaults standardUserDefaults] setValue:[_latestToken key] forKey:@"OAuthKey"];
        _oauthkey = [_latestToken key];
        
        //Save userID and username
        NSArray* parts = [responseBody componentsSeparatedByString:@"&"];
        
        NSString* userID = [[[parts objectAtIndex:2]componentsSeparatedByString:@"="] objectAtIndex:1];
        [[NSUserDefaults standardUserDefaults] setValue:userID forKey:@"userID"];
        _userID = userID;
        
        NSString* username = [[[parts objectAtIndex:3]componentsSeparatedByString:@"="] objectAtIndex:1];
        [[NSUserDefaults standardUserDefaults] setValue:username forKey:@"username"];
        _username = username;
        
        //Tell the application to start updating libraries and collections from server
        [[ZPDataLayer instance] updateLibrariesAndCollectionsFromServer];

        //We do not need the instance any more
        _instance = NULL; 
    }
    
}

- (void)requestTokenTicket:(OAServiceTicket *)ticket didFailWithError:(NSError *)error {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];    
    NSLog(@"Error");
}
- (void)requestAccessToken:(OAServiceTicket *)ticket didFailWithError:(NSError *)error {
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    NSLog(@"Error");
}

@end
