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

@implementation ZPAuthenticationDialog

@synthesize webView;
@synthesize token;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
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
    
    NSString *urlAddress = [NSString stringWithFormat:@"https://www.zotero.org/oauth/authorize?oauth_token=%@",[self.token key]];
    
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
    NSLog(urlString);
    
    //If we are redirected to the front page, we do not need to show the web browser any more
    
    if([urlString hasPrefix:@"https://www.zotero.org/?"]){
        
        //Get permanent key with the temporary key
        NSString* verifier=[[urlString componentsSeparatedByString:@"="] lastObject];
        [self.token setValue:verifier forKey:@"verifier"];
        [[ZPServerConnection instance] makeOAuthRequest:self.token];
        
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
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    // return (interfaceOrientation == UIInterfaceOrientationPortrait);
    return (UIInterfaceOrientationIsLandscape(interfaceOrientation));
    //return YES;
}

@end
