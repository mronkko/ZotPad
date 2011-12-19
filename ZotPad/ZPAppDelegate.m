//
//  ZPAppDelegate.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPAppDelegate.h"
#import "ZPServerConnection.h"
#import "ZPDataLayer.h"
#import "ZPCacheController.h"
#import "ZPAuthenticationProcess.h"

@implementation ZPAppDelegate

@synthesize window = _window;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // If any of the reset options are set process these first
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    if([defaults boolForKey:@"resetusername"]){
        NSLog(@"Reseting username");
        [defaults removeObjectForKey:@"username"];
        [defaults removeObjectForKey:@"userID"];
        [defaults removeObjectForKey:@"OAuthKey"];
        [defaults removeObjectForKey:@"resetusername"];
    }

//    if([defaults boolForKey:@"resetitemdata"]){
        NSLog(@"Reseting itemdata");
        [defaults removeObjectForKey:@"resetitemdata"];
        NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"zotpad.sqlite"];
        [[NSFileManager defaultManager] removeItemAtPath: dbPath error:NULL];
//    }

    if([defaults boolForKey:@"resetfiles"]){
        NSLog(@"Reseting files");
        [defaults removeObjectForKey:@"resetfiles"];
        NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"storage"];
        [[NSFileManager defaultManager] removeItemAtPath: dbPath error:NULL];
    }

    //Set up a background operation for retrieving data
    [[ZPCacheController instance] activate];
    
    // Override point for customization after application launch.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
        UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
        splitViewController.delegate = (id)navigationController.topViewController;
    }
    
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
    
    
}

@end
