//
//  ZPSplitViewController.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 8.4.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "ZPItemListViewController.h"
#import "ZPSplitViewController.h"
#import "ZPFileImportViewController.h"
#import "ZPUploadVersionConflictViewController.h"
#import "ZPFileViewerViewController.h"

@interface ZPSplitViewController ()

@end

@implementation ZPSplitViewController

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
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_USER_INTERFACE_AVAILABLE object:nil];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

-(IBAction)showLogView:(id)sender{
    if(self.interfaceOrientation == UIInterfaceOrientationPortrait || self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown){
        [[(ZPItemListViewController*)[(UINavigationController*)[self.viewControllers objectAtIndex:1] topViewController] masterPopoverController] dismissPopoverAnimated:YES];
    }

    [self performSegueWithIdentifier:@"ShowLogView" sender:NULL];
}

@end
