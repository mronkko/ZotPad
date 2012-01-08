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

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
}
*/

- (void)viewDidLoad {
    
    _instance = self;

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

    NSString* urlString = [[request mainDocumentURL] absoluteString];
    NSLog(@"%@",urlString);
    
    //If we are redirected to the front page, we do not need to show the web browser any more
    
    if([urlString hasPrefix:@"https://www.zotero.org/?"]){
        
        //Get permanent key with the temporary key
        NSString* verifier=[[urlString componentsSeparatedByString:@"="] lastObject];
        
        [[ZPAuthenticationProcess instance] processVerifier:verifier];
        [self dismissModalViewControllerAnimated:YES];
            
        return FALSE;
    }
    else{
        return TRUE;
    }
}
/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
}
*/

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
