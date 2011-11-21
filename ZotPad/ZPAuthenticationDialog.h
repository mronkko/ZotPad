//
//  ZPAuthenticationDialog.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OAToken.h"

@interface ZPAuthenticationDialog : UIViewController <UIApplicationDelegate, UIWebViewDelegate> {
    UIWebView *webView;
    OAToken* token;
}

@property(nonatomic,retain) IBOutlet UIWebView *webView;
@property (retain) OAToken* token;

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;

@end
