//
//  ZPAppDelegate.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPAppDelegate.h"
#import "ZPCacheController.h"
#import "ZPPreferences.h"
#import "ZPLogger.h"
#import "ZPLocalization.h"
#import <DropboxSDK/DropboxSDK.h>
#import "ZPDatabase.h"
#import "ZPAttachmentThumbnailFactory.h"
#include <QuartzCore/QuartzCore.h>

// The size fo the thumbnail that will be shown for an incoming file
#define ATTACHMENT_IMAGE_HEIGHT 580
#define ATTACHMENT_IMAGE_WIDTH 423


@implementation ZPAppDelegate


@synthesize window = _window;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
    //Manual override for userID and Key. Useful for running the code in debugger with other people's credentials.
    /*
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@"" forKey:@"userID"];
    [defaults setObject:@"" forKey:@"OAuthKey"];
    */
    
    //Uncomment these to always reset the app after launch
    [[ZPDatabase instance] resetDatabase];
    [[ZPCacheController instance] performSelectorInBackground:@selector(purgeAllAttachmentFilesFromCache) withObject:NULL];

    [[ZPPreferences instance] checkAndProcessApplicationResetPreferences];
    [[ZPPreferences instance] reload];
    
    //Set up a background operation for retrieving data
    [[ZPCacheController instance] activate];
    
    // Override point for customization after application launch.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
        UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
        splitViewController.delegate = (id)navigationController.topViewController;
    }
    
    NSLog(@"Started");
    
    return YES;
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application{
    NSLog(@"Start freeing memory");
    [ZPZoteroItem dropCache];
    [ZPZoteroCollection dropCache];
    [ZPZoteroLibrary dropCache];
    [ZPLocalization dropCache];
    NSLog(@"Done freeing memory");

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
    
    [[ZPPreferences instance] reload];

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
    NSLog(@"Terminating");

    
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation{
    
    //DropBox authentication
    if ([[DBSession sharedSession] handleOpenURL:url]) {
        if ([[DBSession sharedSession] isLinked]) {
            NSLog(@"App linked successfully!");
            // At this point you can start making API calls
        }
        return YES;
    }
    else{
              
        NSLog(@"Received file %@",url);
        
        //TODO: Refactor: Consider a better place for the code for this alert.

        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Received file from %@",sourceApplication]
                                                          message:nil
                                                         delegate:nil
                                                cancelButtonTitle:nil
                                                otherButtonTitles:nil];

        UIView* fileView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ATTACHMENT_IMAGE_WIDTH, ATTACHMENT_IMAGE_HEIGHT)];

        fileView.layer.borderWidth = 2.0f;
        fileView.backgroundColor = [UIColor whiteColor];
        
        UIImageView* imageView = [[UIImageView alloc] initWithImage:[[ZPAttachmentThumbnailFactory instance] getFiletypeImageForURL:url height:ATTACHMENT_IMAGE_HEIGHT width:ATTACHMENT_IMAGE_WIDTH]];
        [fileView addSubview:imageView];
        imageView.center = fileView.center;

        //Add a label over the view
        
        UILabel* label = [[UILabel alloc] init];
        label.text = [[url pathComponents] lastObject];
        
        label.textColor = [UIColor whiteColor];
        label.backgroundColor = [UIColor clearColor];
        label.textAlignment = UITextAlignmentCenter;
        label.lineBreakMode = UILineBreakModeWordWrap;
        label.numberOfLines = 5;
        label.frame=CGRectMake(50, 200, fileView.frame.size.width-100, fileView.frame.size.height-400);
        
        UIView* background = [[UIView alloc] init];
        background.frame=CGRectMake(40, 190, fileView.frame.size.width-80, fileView.frame.size.height-380);
        background.backgroundColor=[UIColor blackColor];
        background.alpha = 0.5;
        background.layer.cornerRadius = 8;
        
        [fileView addSubview:background];
        [fileView addSubview:label];

        
        [alertView addSubview:fileView];
        [alertView show];
        
        return YES;
    }
    // Add whatever other url handling code your app requires here
    return NO;
}

@end
