//
//  ZPAuthenticationDialog.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"


#import "ZPAuthenticationDialog.h"
#import "ZPServerConnection.h"
#import "OAToken.h"
#import "ZPDataLayer.h"
#import "DSActivityView.h"
#import "ZPCacheController.h"


@implementation ZPAuthenticationDialog


@synthesize webView;

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle



- (void)viewDidLoad {
    
    //Add a loading indicator
    _activityView = [DSBezelActivityView newActivityViewForView:webView];
    [[self webView] setUserInteractionEnabled:FALSE];

    [self makeOAuthRequest: NULL];
    
}

// Takes the user back to start

- (IBAction)loadFirstPage:(id)sender{

    NSString *urlAddress = [NSString stringWithFormat:@"https://www.zotero.org/oauth/authorize?oauth_token=%@&library_access=1&notes_access=1&write_access=1&all_groups=write",_key];
    
    
    //Create a URL object.
    NSURL *url = [NSURL URLWithString:urlAddress];
    
    //URL Requst Object
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
    
    //Load the request in the UIWebView.
    [[self webView] loadRequest:requestObj];
    

    
}

- (void)setKeyAndLoadZoteroSite:(NSString*) key{
    
    _key = key;

    [self loadFirstPage:NULL];

}
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{


    NSString* urlString = [[request mainDocumentURL] absoluteString];
    DDLogVerbose(@"Start loading URL %@",urlString);

    if(_activityView == NULL)
        _activityView = [DSBezelActivityView newActivityViewForView:webView];

    //If we are redirected to the front page, we do not need to show the web browser any more
    
    if([urlString hasPrefix:@"https://www.zotero.org/?oauth_token="]){
        

        //Get permanent key with the temporary key
        NSString* verifier=[[urlString componentsSeparatedByString:@"="] lastObject];

        [self processVerifier:verifier];
            
        return FALSE;
    }
    
    return TRUE;
}

- (void)webViewDidStartLoad:(UIWebView *)webView{
}

- (void)webViewDidFinishLoad:(UIWebView *)webView{
    if(_activityView != NULL){
        [DSBezelActivityView removeViewAnimated:YES];
        [[self webView] setUserInteractionEnabled:TRUE];
        _activityView = NULL;
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    // return (interfaceOrientation == UIInterfaceOrientationPortrait);
    // return (UIInterfaceOrientationIsLandscape(interfaceOrientation));
    return YES;
}

#pragma mark - Authentication process


-(void) processVerifier:(NSString*)verifier{
    [_latestToken setValue:verifier forKey:@"verifier"];
    [self makeOAuthRequest:_latestToken];
}

- (void) makeOAuthRequest:(OAToken *) token {
    //TODO: move these to secrets
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
        
        [self setKeyAndLoadZoteroSite:[_latestToken key]];
    }
    
}

/*
 This is the second part where we get the permanent token
 */

- (void)requestAccessToken:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data {
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self dismissModalViewControllerAnimated:YES];

    if (ticket.didSucceed) {
        NSString *responseBody = [[NSString alloc] initWithData:data
                                                       encoding:NSUTF8StringEncoding];
        _latestToken = [[OAToken alloc] initWithHTTPResponseBody:responseBody];
        
        
        DDLogVerbose(@"Got access token");
        
        //Save the key to preferences
        [[ZPPreferences instance] setOAuthKey:[_latestToken key]];
        _oauthkey = [_latestToken key];
        
        //Save userID and username
        NSArray* parts = [responseBody componentsSeparatedByString:@"&"];
        
        NSString* userID = [[[parts objectAtIndex:2]componentsSeparatedByString:@"="] objectAtIndex:1];
        [[ZPPreferences instance] setUserID:userID];
        _userID = userID;
        
        NSString* username = [[[parts objectAtIndex:3]componentsSeparatedByString:@"="] objectAtIndex:1];
        [[ZPPreferences instance] setUsername:username];
        _username = username;
        
        //Tell the application to start updating libraries and collections from server
        //TODO: Refactor to use notifications
        [[ZPCacheController instance] updateLibrariesAndCollectionsFromServer];
        
    }
    
}

- (void)requestTokenTicket:(OAServiceTicket *)ticket didFailWithError:(NSError *)error {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];    
    DDLogError(@"Error in requesting token ticket: %@",error);
}
- (void)requestAccessToken:(OAServiceTicket *)ticket didFailWithError:(NSError *)error {
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    DDLogError(@"Error in requesting access token: %@",error);
}



@end
