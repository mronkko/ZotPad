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

@implementation ZPServerConnection

static ZPServerConnection* _instance = nil;

-(id)init
{
    self = [super init];
    
    //Load the key from preferences
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    self->_oauthkey = [defaults objectForKey:@"OAuthKey"];

	
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

@end
