//
//  ZPAppDelegate.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DDFileLogger.h"
#import "DBRestClient.h"

@interface ZPAppDelegate : UIResponder <UIApplicationDelegate, DBRestClientDelegate>{
    DBRestClient* _restClient;
}

- (void) startAuthenticationSequence;
- (void) _uploadFolderToDropBox:(DBRestClient*) client toPath:(NSString*)toPath fromPath:(NSString*) fromPath;

@property (retain) DDFileLogger* fileLogger;
@property (strong, nonatomic) UIWindow *window;
    
@end
