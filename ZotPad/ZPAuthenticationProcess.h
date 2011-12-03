//
//  ZPAuthenticationProcess.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/1/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OAuthConsumer.h"
#import "OAToken.h"

@interface ZPAuthenticationProcess : NSObject
{
    //The Oauht key to use
    NSString* _oauthkey;
    NSString* _username;
    NSString* _userID;
    
    OAToken* _latestToken;
    BOOL _isActive;
}

+ (ZPAuthenticationProcess*)instance;

// Methods used in the OAuth authentication
- (void) makeOAuthRequest: (OAToken *) token;
- (void)requestTokenTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data;
- (void) startAuthentication;

-(void) processVerifier:(NSString*)verifier;

-(BOOL) isActive;

@end
