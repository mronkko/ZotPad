//
//  ZPLogViewController.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 30.6.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPCore.h"
#import "ZPLogViewController.h"
#import "ZPAppDelegate.h"
#import "DDFileLogger.h"

@interface ZPLogViewController ()

@end

@implementation ZPLogViewController

@synthesize logView;

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
    [logView scrollRangeToVisible:NSMakeRange([logView.text length], 0)];
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
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"User Manual" ofType:@"pdf"];  
    UIDocumentInteractionController* manual = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath: filePath]];
    [manual presentPreviewAnimated:YES];
}
-(IBAction)onlineSupport:(id)sender{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.zotpad.com/node/3"]];
}
-(IBAction)emailSupport:(id)sender{
    MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
    [mailController setSubject:@"Support request"];
    [mailController setToRecipients:[NSArray arrayWithObject:@"support@zotpad.com"]];
    [mailController setMessageBody:[NSString stringWithFormat:@"<Please describe your problem here>\n\n\n\nMy userID is %@ and API key is %@. My current log file is attached.",[[ZPPreferences instance] userID], [[ZPPreferences instance] OAuthKey], nil] isHTML:NO];
    
    ZPAppDelegate* appDelegate = (ZPAppDelegate*) [[UIApplication sharedApplication] delegate];
    NSString* logPath = [appDelegate.fileLogger.logFileManager.sortedLogFilePaths objectAtIndex:0];
    
    [mailController addAttachmentData:[NSData dataWithContentsOfFile:logPath] mimeType:@"text/plain" fileName:@"log.txt"];
    
    [self presentModalViewController:mailController animated:YES];     
}
-(IBAction)dismiss:(id)sender{
    [self dismissModalViewControllerAnimated:YES];
}

@end
