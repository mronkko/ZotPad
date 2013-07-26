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
#import "ZPUserSupport.h"

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
    [ZPUserSupport openSupportSystemFromParentViewController:self];
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
