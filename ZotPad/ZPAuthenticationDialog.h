//
//  ZPAuthenticationDialog.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DSActivityView.h"
#import "OAuthConsumer.h"
#import "OAToken.h"
#import "ZPModalViewController.h"

@interface ZPAuthenticationDialog : ZPModalViewController <UIApplicationDelegate, UIWebViewDelegate> {
    
    DSActivityView* _activityView;
    NSString* _key;

    //The Oauht key to use
    NSString* _oauthkey;
    NSString* _username;
    NSString* _userID;
    
    OAToken* _latestToken;
    BOOL _isActive;

}

@property(nonatomic,retain) IBOutlet UIWebView *webView;

+ (void) presentInstanceModally;
+ (BOOL) isPresenting;

- (void)setKeyAndLoadZoteroSite:(NSString*)key;
- (IBAction)loadFirstPage:(id)sender;

- (void) makeOAuthRequest: (OAToken *) token;
- (void)requestTokenTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data;

-(void) processVerifier:(NSString*)verifier;

@end
