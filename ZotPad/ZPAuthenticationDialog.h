//
//  ZPAuthenticationDialog.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface ZPAuthenticationDialog : UIViewController <UIApplicationDelegate, UIWebViewDelegate> {
    UIWebView* webView;


}

@property(nonatomic,retain) IBOutlet UIWebView *webView;

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;

+(ZPAuthenticationDialog*) instance;

- (void)setKeyAndLoadZoteroSite:(NSString*)key;


@end
