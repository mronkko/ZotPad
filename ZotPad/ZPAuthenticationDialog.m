//
//  ZPAuthenticationDialog.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPAuthenticationDialog.h"
#import "ZPServerConnection.h"
#import "OAToken.h"
#import "ZPDataLayer.h"
#import "ZPAuthenticationProcess.h"
#import "../DSActivityView/Sources/DSActivityView.h"

#import "ZPLogger.h"

@implementation ZPAuthenticationDialog


@synthesize webView;

static ZPAuthenticationDialog* _instance = nil;

+(ZPAuthenticationDialog*) instance {
    return _instance;
}


- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle



- (void)viewDidLoad {
    
    _instance = self;
    //Add a loading indicator
    _activityView = [DSBezelActivityView newActivityViewForView:webView];
    [[self webView] setUserInteractionEnabled:FALSE];
    
}

- (void)setKeyAndLoadZoteroSite:(NSString*) key{
    NSLog(@"Starting loading Zotero website");
    
    NSString *urlAddress = [NSString stringWithFormat:@"https://www.zotero.org/oauth/authorize?oauth_token=%@",key];
    
    //Create a URL object.
    NSURL *url = [NSURL URLWithString:urlAddress];
    
    //URL Requst Object
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
    
    //Load the request in the UIWebView.
    [[self webView] loadRequest:requestObj];

    
    NSLog(@"Done loading");

}
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{

    NSLog(@"Requesting new page %@ method: %@",request.mainDocumentURL,request.HTTPMethod);
    //These are valid URL prefixes in the authentication workflow and should be loaded
    NSArray* validURLs = [NSArray arrayWithObjects:@"https://www.zotero.org/oauth/authorize?oauth_token=",
                          @"https://www.zotero.org/settings/keys/new?oauth=1&oauth_token=",
                          @"https://www.zotero.org/?oauth_token=",
                          @"https://www.zotero.org/user/logout",
                          @"https://www.zotero.org/user/login",nil];
    

    NSString* urlString = [[request mainDocumentURL] absoluteString];
    
    //If we are redirected to the front page, we do not need to show the web browser any more
    
    if([urlString hasPrefix:@"https://www.zotero.org/?oauth_token="]){
        
        //Get permanent key with the temporary key
        NSString* verifier=[[urlString componentsSeparatedByString:@"="] lastObject];

        [self dismissModalViewControllerAnimated:YES];

        [[ZPAuthenticationProcess instance] processVerifier:verifier];
            
        return FALSE;
    }
    //All POST requests are loaded
    else if([request.HTTPMethod isEqualToString:@"POST"]) return TRUE;
    //Loop through the white list and load the url if it should be loaded
    else{
        NSString* validURL;
        for(validURL in validURLs){
            if([urlString hasPrefix:validURL]) return TRUE;
        }
    }

    NSLog(@"URL %@ is not whitelisted in the authentication sequence",urlString);
    return FALSE;
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
    
    _instance = NULL;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    // return (interfaceOrientation == UIInterfaceOrientationPortrait);
    // return (UIInterfaceOrientationIsLandscape(interfaceOrientation));
    return YES;
}





@end
