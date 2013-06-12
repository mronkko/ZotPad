//
//  ZPLogViewController.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 30.6.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"
#import "ZPLogViewController.h"
#import "ZPAppDelegate.h"
#import "DDFileLogger.h"
#import "CMPopTipView.h"
#import "UserVoice.h"
#import "UVSession.h"
#import "UVClientConfig.h"
#import "ZPSecrets.h"

@interface ZPLogViewController (){
    MFMailComposeViewController *mailController;
}

@end

@implementation ZPLogViewController

@synthesize logView,manualButton;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    ZPAppDelegate* appDelegate = (ZPAppDelegate*) [[UIApplication sharedApplication] delegate];
    NSArray* logFiles = appDelegate.fileLogger.logFileManager.sortedLogFilePaths;
    if(logFiles.count>0){
        NSString* logPath = [logFiles objectAtIndex:0];

        logView.text = [[NSString alloc] initWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:NULL];
    }
    else logView.text = @"";
    
}
- (void) viewWillAppear:(BOOL)animated{
    [logView scrollRangeToVisible:NSMakeRange([logView.text length], 0)];
}
- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:YES];

    if([[NSUserDefaults standardUserDefaults] objectForKey:@"hasPresentedSecondaryHelpPopover"]==NULL){
        CMPopTipView* helpPopUp = [[CMPopTipView alloc] initWithMessage:@"Tap here for help"];
        [helpPopUp presentPointingAtBarButtonItem:manualButton animated:YES];
        [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:@"hasPresentedSecondaryHelpPopover"];
    }

}
- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

-(IBAction)showManual:(id)sender{
    QLPreviewController* ql = [[QLPreviewController alloc] init];
    ql.dataSource = self;
    [self presentModalViewController:ql animated:YES];
}

-(IBAction)contactSupport:(id)sender{
    
    if(USERVOICE_API_KEY == nil || USERVOICE_SECRET == nil){
        [[[UIAlertView alloc] initWithTitle:@"Not implemented"
                                    message:@"Feedback and knowledge base are not available in this build because UserVoice key or secret is missing."
                                   delegate:nil
                          cancelButtonTitle:@"Cancel"
                          otherButtonTitles:nil]show];

    }
    else{
        UVConfig *config = [UVConfig configWithSite:@"zotpad.uservoice.com"
                                             andKey:(NSString*)USERVOICE_API_KEY
                                          andSecret:(NSString*)USERVOICE_SECRET];
        
        NSArray* logLines = [self.logView.text componentsSeparatedByString:@"\n"];
        NSInteger logLineCount = logLines.count;
        NSString* logText;
        if(logLineCount> 300){
            logLines = [logLines subarrayWithRange:NSMakeRange(logLines.count-300, 300)];
        }
        
        logText =[logLines componentsJoinedByString:@"\n"];
        
        if(logLineCount>300){
            logText = [NSString stringWithFormat:@"%i lines of log (omitting lines 1-%i)\n\n%@",logLineCount,logLineCount-300,logText];
        }
        else{
            logText = [NSString stringWithFormat:@"%i lines of log\n\n%@",logLineCount,logText];
        }
        
        NSString* technicalInfo = [NSString stringWithFormat:@"\n\n --- Technical info ---\n\n%@ %@ (build %@)\n%@ (iOS %@)\nuserID: %@\nAPI key: %@\n\n --- Settings ----\n\n%@\n\n --- Application log ----\n\n%@",
                                   [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"],
                                   [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                                   [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                                   [[UIDevice currentDevice] model],
                                   [[UIDevice currentDevice] systemVersion],
                                   [ZPPreferences userID],
                                   [ZPPreferences OAuthKey],
                                   [ZPPreferences preferencesAsDescriptiveString],
                                   logText];
        
        
        NSMutableArray* attachments = [[NSMutableArray alloc] init];
        
        //If we have a log file, include that
        
        ZPAppDelegate* appDelegate = (ZPAppDelegate*) [[UIApplication sharedApplication] delegate];
        NSArray* logFiles = appDelegate.fileLogger.logFileManager.sortedLogFilePaths;
        if(logFiles.count>0){
            NSString* logPath = [logFiles objectAtIndex:0];
            [attachments addObject:logPath];
        }

        if([ZPPreferences includeDatabaseWithSupportRequest]){
            [attachments addObject:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"zotpad.sqlite"]];
        }
        // Do we want to include a file list

        if([ZPPreferences includeFileListWithSupportRequest]){
            NSString* documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
            NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:NULL];
            
            NSString* fileListFile = [NSTemporaryDirectory() stringByAppendingPathComponent: @"files.txt"];
            NSString* fileListString  = [directoryContent componentsJoinedByString:@"\n"];
            
            [fileListString writeToFile:fileListFile
                             atomically:NO
                               encoding:NSStringEncodingConversionAllowLossy
                                  error:nil];

            [attachments addObject:fileListFile];
            
        }
        
        config.attachmentFilePaths = attachments;
        config.extraTicketInfo = technicalInfo;
        
        [UserVoice presentUserVoiceInterfaceForParentViewController:self andConfig:config];
    }
}


-(IBAction)manageKey:(id)sender{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"https://www.zotero.org/settings/keys/edit/" stringByAppendingString:[ZPPreferences OAuthKey]]]];
}

-(IBAction)dismiss:(id)sender{
    [self dismissModalViewControllerAnimated:YES];
}

-(void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    [mailController dismissModalViewControllerAnimated:YES];
    mailController = NULL;
}
- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller{
    return 1;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index{
    NSString* manualType;
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        manualType = @"UserManual"; 
    }
    else{
        manualType = @"iphone"; 
    }
    NSString *filePath = [[NSBundle mainBundle] pathForResource:manualType ofType:@"pdf"];  
    return [NSURL fileURLWithPath: filePath];
    
}
@end
