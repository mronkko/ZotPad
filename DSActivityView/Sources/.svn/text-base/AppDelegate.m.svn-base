//
//  AppDelegate.m
//  DSActivityView Demo
//
//  Created by David Sinclair on 2009-07-29.
//  Copyright Dejal Systems, LLC 2009-2011. All rights reserved.
//

#import "AppDelegate.h"
#import "RootViewController.h"
#import "DSActivityView.h"


@implementation AppDelegate

@synthesize window, navigationController, defaultImageView;


#pragma mark -
#pragma mark Application lifecycle

- (void)applicationDidFinishLaunching:(UIApplication *)application;
{    
    // Demo of using a simple loading view with a default background image:
	[window addSubview:defaultImageView];
    [window makeKeyAndVisible];
    
    // No need for a property for the activity view:
    [DSActivityView newActivityViewForView:window];
    
    // Normally you'd do other work to load the data etc, then remove the activity view; faking that delay here:
    [self performSelector:@selector(setupWindow) withObject:nil afterDelay:1.0];
}

- (void)setupWindow;
{
	[window addSubview:[navigationController view]];
    [defaultImageView removeFromSuperview];
    
    // Easily remove the activity view (there's also animated variations for the bezel and keyboard styles):
    [DSActivityView removeView];
}


- (void)applicationWillTerminate:(UIApplication *)application;
{
	// Save data if appropriate
}


#pragma mark -
#pragma mark Memory management

- (void)dealloc;
{
	[navigationController release];
	[window release];
	[super dealloc];
}


@end

