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
#import "ZPHelpPopover.h"
#import "UserVoice.h"
#import "UVSession.h"
#import "UVClientConfig.h"

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
    NSString* logPath = [appDelegate.fileLogger.logFileManager.sortedLogFilePaths objectAtIndex:0];

    logView.text = [[NSString alloc] initWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:NULL];
//    [logView scrollRangeToVisible:NSMakeRange([logView.text length], 0)];
}
- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:YES];
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        if([[NSUserDefaults standardUserDefaults] objectForKey:@"hasPresentedSecondaryHelpPopover"]==NULL){
            [ZPHelpPopover displayHelpPopoverFromToolbarButton:manualButton];
            [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:@"hasPresentedSecondaryHelpPopover"];
        }
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

#ifdef BETA

-(IBAction)knowledgeBase:(id)sender{
    [[[UIAlertView alloc] initWithTitle:@"Not implemented"
                                message:@"Feedback and knowledge base are not available in beta builds."
                               delegate:nil
                      cancelButtonTitle:@"Cancel"
                      otherButtonTitles:nil]show];
}

#else

#import "ZPSecrets.h"

-(IBAction)knowledgeBase:(id)sender{
    UVConfig *config = [UVConfig configWithSite:@"zotpad.uservoice.com"
                                         andKey:USERVOICE_API_KEY
                                      andSecret:USERVOICE_SECRET];
    
    //Allow starting tickets only by email.
    
    [[[UVSession currentSession] clientConfig] setTicketsEnabled:NO];
    
    [UserVoice presentUserVoiceInterfaceForParentViewController:self andConfig:config];
}

#endif

-(IBAction)manageKey:(id)sender{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"https://www.zotero.org/settings/keys/edit/" stringByAppendingFormat:[[ZPPreferences instance] OAuthKey]]]];
}

-(IBAction)emailSupport:(id)sender{
    if([MFMailComposeViewController canSendMail]){
        mailController = [[MFMailComposeViewController alloc] init];
        [mailController setSubject:@"Support request"];
        [mailController setToRecipients:[NSArray arrayWithObject:@"support@zotpad.com"]];
        [mailController setMessageBody:[NSString stringWithFormat:@"<Please describe your problem here>\n\n\n\nMy userID is %@ and API key is %@. My current log file is attached.",[[ZPPreferences instance] userID], [[ZPPreferences instance] OAuthKey], nil] isHTML:NO];
        
        ZPAppDelegate* appDelegate = (ZPAppDelegate*) [[UIApplication sharedApplication] delegate];
        NSString* logPath = [appDelegate.fileLogger.logFileManager.sortedLogFilePaths objectAtIndex:0];
        NSData* data = [NSData dataWithContentsOfFile:logPath];
        [mailController addAttachmentData:data mimeType:@"text/plain" fileName:@"log.txt"];
        
        mailController.mailComposeDelegate = self;
        
        [self presentModalViewController:mailController animated:YES];     
    }
    else{
        [[[UIAlertView alloc] initWithTitle:@"Email not available" message:@"Your device is not configured for sending email." delegate:NULL cancelButtonTitle:@"Cancel" otherButtonTitles:nil] show];
    }
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
