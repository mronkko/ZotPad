//
//  ZPAppDelegate.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DDFileLogger.h"

@interface ZPAppDelegate : UIResponder <UIApplicationDelegate>

- (void) dismissViewControllerHierarchy;
- (void) startAuthenticationSequence;

@property (retain) DDFileLogger* fileLogger;
@property (strong, nonatomic) UIWindow *window;
    
@end
