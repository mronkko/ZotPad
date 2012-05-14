//
//  ZPAuthenticationDialog.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPCore.h"


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

    NSLog(@"Starting loading Zotero website");
    
    [self loadFirstPage:NULL];
    
    NSLog(@"Done loading");

}
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{


    NSString* urlString = [[request mainDocumentURL] absoluteString];
    NSLog(@"Start loading URL %@",urlString);
    
    //If we are redirected to the front page, we do not need to show the web browser any more
    
    if([urlString hasPrefix:@"https://www.zotero.org/?oauth_token="]){
        
        //Get permanent key with the temporary key
        NSString* verifier=[[urlString componentsSeparatedByString:@"="] lastObject];

        [self dismissModalViewControllerAnimated:YES];

        [[ZPAuthenticationProcess instance] processVerifier:verifier];
            
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
