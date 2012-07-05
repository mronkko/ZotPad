//
//  ZPAppDelegate.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"
#import "ZPAppDelegate.h"
#import "ZPCacheController.h"
#import "ZPPreferences.h"
#import "ZPLocalization.h"
#import <DropboxSDK/DropboxSDK.h>
#import "ZPDatabase.h"
#import "ZPFileImportViewController.h"
#import "ZPFileChannel_Dropbox.h"
#import "ZPAuthenticationDialog.h"

//Setting up the logger
#import "DDTTYLogger.h"
#import "DDFileLogger.h"
#import "TestFlightLogger.h"
#import "CompressingLogFileManager.h"

@interface ZPFileLogFormatter : NSObject <DDLogFormatter>{
    NSInteger level;
    NSDateFormatter* dateFormatter;
}

@end

@implementation ZPFileLogFormatter

- (id) initWithLevel:(NSInteger) level{
    self = [super init];
    self->level = level;
    
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd-MM-yyyy HH:mm::ss"];
    
    return self;
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage{
    
    if((logMessage->logFlag & self->level) != logMessage->logFlag) return NULL;

    NSString* dateString = [dateFormatter stringFromDate:[NSDate date]];

    if((logMessage->logFlag & LOG_LEVEL_ERROR) == logMessage->logFlag){
        return [NSString stringWithFormat:@"%@ ERROR: %@",dateString, logMessage->logMsg];
    }
    else if((logMessage->logFlag & LOG_LEVEL_WARN) == logMessage->logFlag){
        return [NSString stringWithFormat:@"%@ WARN : %@",dateString, logMessage->logMsg];
    }
    else if((logMessage->logFlag & LOG_LEVEL_INFO) == logMessage->logFlag){
        return [NSString stringWithFormat:@"%@ INFO : %@",dateString, logMessage->logMsg];
    }
    else if((logMessage->logFlag & LOG_LEVEL_VERBOSE) == logMessage->logFlag){
        return [NSString stringWithFormat:@"%@ DEBUG : %@",dateString, logMessage->logMsg];
    }
    else return NULL;
}

@end
@implementation ZPAppDelegate


@synthesize window = _window;
@synthesize fileLogger;


- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{

#ifdef DEBUG
    [TestFlight setDeviceIdentifier:[[UIDevice currentDevice] uniqueIdentifier]];
    
    [TestFlight takeOff:@"5e753f234f33fc2bddf4437600037fbf_NjcyMjEyMDEyLTA0LTA5IDE0OjUyOjU0LjE4MDQwMg"];

    TestFlightLogger* tfLogger = [[TestFlightLogger alloc] initWithTeamToken:@"5e753f234f33fc2bddf4437600037fbf_NjcyMjEyMDEyLTA0LTA5IDE0OjUyOjU0LjE4MDQwMg"];
    tfLogger.logFormatter = [[ZPFileLogFormatter alloc] initWithLevel:LOG_LEVEL_VERBOSE];
    [DDLog addLogger:tfLogger];
#else
    if([[ZPPreferences instance] reportErrors]) [TestFlight takeOff:@"5e753f234f33fc2bddf4437600037fbf_NjcyMjEyMDEyLTA0LTA5IDE0OjUyOjU0LjE4MDQwMg"];

#endif
    
    CompressingLogFileManager* logFileManager = [[CompressingLogFileManager alloc] initWithLogsDirectory:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
    self.fileLogger = [[DDFileLogger alloc] initWithLogFileManager:logFileManager];
    self.fileLogger.rollingFrequency = 60 * 60 *24; // 24 hour rolling
    self.fileLogger.logFileManager.maximumNumberOfLogFiles = 7; // one week of logs
    self.fileLogger.logFormatter = [[ZPFileLogFormatter alloc] initWithLevel:LOG_LEVEL_INFO];
    [DDLog addLogger:self.fileLogger]; 


    
    DDLogInfo(@"Starting");

     //Manual override for userID and Key. Useful for running the code in debugger with other people's credentials.
    

    /*
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@"" forKey:@"userID"];
    [defaults setObject:@"" forKey:@"OAuthKey"];

    //Uncomment these to always reset the app after launch
    [[ZPDatabase instance] resetDatabase];
    [[ZPCacheController instance] performSelectorInBackground:@selector(purgeAllAttachmentFilesFromCache) withObject:NULL];
    */
    
    [[ZPPreferences instance] checkAndProcessApplicationResetPreferences];

     
    
    // Override point for customization after application launch.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;

        if ([splitViewController respondsToSelector:@selector(setPresentsWithGesture:)]) {
            [splitViewController setPresentsWithGesture:NO];
        }

        UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
        splitViewController.delegate = (id)navigationController.topViewController;
    }

    //These will trigger authentication

    [ZPFileChannel_Dropbox linkDroboxIfNeeded];
    [[ZPCacheController instance] performSelectorInBackground:@selector(updateLibrariesAndCollectionsFromServer) withObject:NULL];

    DDLogInfo(@"Started");
    
    return YES;
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application{
    DDLogInfo(@"Start freeing memory");
    [ZPZoteroItem dropCache];
    [ZPZoteroCollection dropCache];
    [ZPZoteroLibrary dropCache];
    [ZPLocalization dropCache];
    DDLogInfo(@"Done freeing memory");

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
    [ZPFileChannel_Dropbox linkDroboxIfNeeded];


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
    DDLogInfo(@"Terminating");

    
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation{
    
    //DropBox authentication
    if ([[DBSession sharedSession] handleOpenURL:url]) {
        if ([[DBSession sharedSession] isLinked]) {
            DDLogInfo(@"App linked successfully with DropBox");
            // At this point you can start making API calls
        }
        return YES;
    }
    else{
              
        //Is the file recognized?
        
        ZPZoteroAttachment* attachment = [ZPZoteroAttachment dataObjectForAttachedFile:url.absoluteString];
        
        if(attachment == NULL){
            DDLogInfo(@"Received an unknown file %@ from %@",[url lastPathComponent],sourceApplication);
            [[[UIAlertView alloc] initWithTitle:@"Unknown file" message:[NSString stringWithFormat:@"ZotPad could not identify a Zotero item for file '%@' received from %@. The file will be ignored.",[url lastPathComponent],[[sourceApplication componentsSeparatedByString:@"."] lastObject]] delegate:NULL cancelButtonTitle:@"Cancel" otherButtonTitles: nil] show];
        }
        else{
            DDLogInfo(@"A file %@ from %@",[url lastPathComponent],sourceApplication);
            
            [self dismissViewControllerHierarchy];
            [self.window.rootViewController performSegueWithIdentifier:@"Import" sender:url];
            [[ZPCacheController instance] addAttachmentToUploadQueue:attachment withNewFile:url];
        }
                                                                
        
        //Clean up inbox
        NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Inbox"];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:dbPath]){
            [[NSFileManager defaultManager] removeItemAtPath: dbPath error:NULL];   
        }

        return YES;
    }
    // Add whatever other url handling code your app requires here
    return NO;
}

- (void) startAuthenticationSequence{

    if([NSThread isMainThread]){
        UIViewController* root = self.window.rootViewController;  
        
        if(root.presentedViewController == NULL || ![root.presentedViewController isKindOfClass:[ZPAuthenticationDialog class]]){
            [self dismissViewControllerHierarchy];
            [root performSegueWithIdentifier:@"Authentication" sender:NULL];
        }
    }
    else{
        [self performSelectorOnMainThread:@selector(startAuthenticationSequence) withObject:NULL waitUntilDone:NO];
    }

}

-(void) dismissViewControllerHierarchy{
   
    //Find the top most viewcontroller
    UIViewController* viewController = self.window.rootViewController;
    while(viewController.presentedViewController) viewController = viewController.presentedViewController;
    
    //Start dismissing modal views
    while(viewController != self.window.rootViewController){
        UIViewController* parent = viewController.presentingViewController;
        [viewController dismissModalViewControllerAnimated:NO];
        viewController = parent;
    }
    
}
@end
