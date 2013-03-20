//
//  ZPAuthenticationDialog.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "ZPAuthenticationDialog.h"
#import "OAToken.h"
#import "DSActivityView.h"
#import "ZPSecrets.h"

// Needed for screen shots
#import <QuartzCore/QuartzCore.h>

@interface ZPAuthenticationDialog (){
    UIView* _webViewOverlay;
}

-(UIImage*)_captureScreen:(UIView*) viewToCapture;

@end
@implementation ZPAuthenticationDialog


@synthesize webView;

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle


- (void)viewWillAppear:(BOOL)animated{

    [super viewWillAppear:animated];
    
    //Cover the view with a blank view so that partial rendering is not displayed
    _webViewOverlay = [[UIView alloc] initWithFrame:self.webView.bounds];
    _webViewOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _webViewOverlay.backgroundColor = [UIColor whiteColor];
    [self.webView addSubview:_webViewOverlay];

    [self makeOAuthRequest: NULL];
    
    //Add a loading indicator
    _activityView = [DSBezelActivityView newActivityViewForView:webView];
    
    [[self webView] setUserInteractionEnabled:FALSE];

}

// Takes the user back to start

- (IBAction)loadFirstPage:(id)sender{

    NSString *urlAddress = [NSString stringWithFormat:@"https://www.zotero.org/oauth/authorize?oauth_token=%@&library_access=1&notes_access=1&write_access=1&all_groups=write&fullsite=0",_key];
    
    
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
- (BOOL)webView:(UIWebView *)aWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{


    NSString* urlString = [[request mainDocumentURL] absoluteString];
    DDLogVerbose(@"Start loading URL %@",urlString);



    NSString* requestBody = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
    if([urlString isEqualToString:@"objc:activate"]){
        if(_activityView != NULL){
            [DSBezelActivityView removeViewAnimated:YES];
            [_webViewOverlay removeFromSuperview];
            [aWebView setUserInteractionEnabled:TRUE];
            _activityView = NULL;
        }

        return FALSE;
    }
    else if([requestBody rangeOfString:@"&revoke="].location != NSNotFound){
        
        [[[UIAlertView alloc] initWithTitle:@"API key required"
                                   message:@"You need to save the API key to use ZotPad"
                                  delegate:NULL
                         cancelButtonTitle:@"OK"
                          otherButtonTitles: nil] show];
        return FALSE;
    }
    /*
    else if([urlString isEqualToString:@"https://www.zotero.org/settings/storage"]){
        [[[UIAlertView alloc] initWithTitle:@"Blocked"
                                    message:@"Accessing storage plans through ZotPad is blocked because Apple does not allow subscriptions to third party services within iPad/iPhone apps."
                                   delegate:NULL
                          cancelButtonTitle:@"OK"
                          otherButtonTitles: nil] show];
        return FALSE;
        
    }
    else if([urlString isEqualToString:@"https://www.zotero.org/user/register"]){
        [[[UIAlertView alloc] initWithTitle:@"Blocked"
                                    message:@"Creating Zotero user accounts through ZotPad is blocked because Apple does not allow subscriptions to third party services within iPad/iPhone apps."
                                   delegate:NULL
                          cancelButtonTitle:@"OK"
                          otherButtonTitles: nil] show];
        return FALSE;
     
    }
    */
    //If we are redirected to the front page, we do not need to show the web browser any more

    if([urlString hasPrefix:@"https://www.zotero.org/?oauth_token="]){
        
        //Get permanent key with the temporary key
        NSString* verifier=[[urlString componentsSeparatedByString:@"="] lastObject];

        [self processVerifier:verifier];
            
        return FALSE;
    }
    
    return TRUE;
}

- (void)webViewDidStartLoad:(UIWebView *)aWebView{
    
    if(_activityView == NULL){
        // Add a screenshot on top of the UIWebView so that partial rendering does not show
        UIImage* screenshot = [self _captureScreen:aWebView];
        _webViewOverlay = [[UIImageView alloc] initWithImage:screenshot];
        _webViewOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [aWebView addSubview:_webViewOverlay];
        _activityView = [DSBezelActivityView newActivityViewForView:webView];
        
    }

}

- (void)webViewDidFinishLoad:(UIWebView *)aWebView{
    
    // Remove the links
    [aWebView stringByEvaluatingJavaScriptFromString:@"try{\
        element = document.getElementsByTagName('nav')[0];\
        element.parentNode.removeChild(element);\
        element =  document.getElementsByTagName('header')[0];\
        element.parentNode.removeChild(element);\
     }\
     catch(err){}\
     window.location = 'objc:activate'"];

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

    //Check that the keys are installed and crash if not
    if(ZOTERO_KEY == nil || ZOTERO_SECRET == nil) [NSException raise:@"Missing credentials exception" format:@"Authentication key or secret for Zotero is missing. Please see the file ZotPad/Secrets.h for details"];
    
    OAConsumer *consumer = [[OAConsumer alloc] initWithKey:ZOTERO_KEY
                                        secret:ZOTERO_SECRET];
    
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
        [ZPPreferences setOAuthKey:[_latestToken key]];
        _oauthkey = [_latestToken key];
        
        //Save userID and username
        NSArray* parts = [responseBody componentsSeparatedByString:@"&"];
        
        NSString* userID = [[[parts objectAtIndex:2]componentsSeparatedByString:@"="] objectAtIndex:1];
        [ZPPreferences setUserID:userID];
        _userID = userID;
        
        NSString* username = [[[parts objectAtIndex:3]componentsSeparatedByString:@"="] objectAtIndex:1];
        [ZPPreferences setUsername:username];
        _username = username;
        
        //Tell the application to start updating libraries and collections from server
        [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ZOTERO_AUTHENTICATION_SUCCESSFUL object:nil];
 
        
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

-(UIImage*)_captureScreen:(UIView*) viewToCapture
{
    UIGraphicsBeginImageContext(viewToCapture.bounds.size);
    [viewToCapture.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return viewImage;
}

@end
