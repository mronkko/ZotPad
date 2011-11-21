//
//  ZPAppDelegate.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPAppDelegate.h"
#import "ZPAuthenticationDialog.h"
#import "ZPServerConnection.h"


@implementation ZPAppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //Copy a template database to documents folder if there is no database currently
    
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *sourceFile = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"zotpad.sqlite"];
    
    NSString *toFile = [documentsDirectory stringByAppendingPathComponent:@"zotpad.sqlite"];

    if(![[NSFileManager defaultManager] fileExistsAtPath:toFile]){
        NSLog(@"Source Path: %@\n Target Path: %@", sourceFile, toFile);

        NSError *error;
    
        if([[NSFileManager defaultManager] copyItemAtPath:sourceFile toPath:toFile error:&error]){
            NSLog(@"Database successfully copied");
        } else {
            NSLog(@"Error description-%@ \n", [error localizedDescription]);
            NSLog(@"Error reason-%@", [error localizedFailureReason]);
        }
    }
    else{
        NSLog(@"Existing database found at: %@", toFile);
    }


    
    /*

    //If a Zip archive is found in the documents directory, unzip it
    //TODO: Make this run in background and fix it so that it works
    
    
    NSString* filePath = [NSString stringWithFormat:@"%@/storage.zip",documentsDirectory];

    
    if([[NSFileManager defaultManager] fileExistsAtPath:filePath]){
        
        NSLog([NSString stringWithFormat:@"Found storage.zip (%i bytes) in documents folder, preparing to unzip", [[[NSFileManager defaultManager]  attributesOfItemAtPath:filePath error:nil] fileSize]]);

        // Trouble shooting code to get the size of the file with C.  
        char* filen = [filePath UTF8String];
        FILE *fp;
        printf(filen);
        if(fp=fopen(filen, "rb")){
            fseeko(fp,0,SEEK_END);
            NSLog([NSString stringWithFormat:@"File size is %i", ftello(fp)]);
        }
      
        
        ZipArchive *zipArchive = [[ZipArchive alloc] init];
    
        if([zipArchive UnzipOpenFile:filePath]) {
        
        
        
            if ([zipArchive UnzipFileTo:documentsDirectory overWrite:YES]) {
			//unzipped successfully
                NSLog(@"Archive unzip Success");
//			[self.fileManager removeItemAtPath:filePath error:NULL];
            } else {
                NSLog(@"Failure To Unzip Archive");
            }
        
        } else  {
		NSLog(@"Failure To Open Archive");
        }    
    } 
     
     */

    
    
    
    


    
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
