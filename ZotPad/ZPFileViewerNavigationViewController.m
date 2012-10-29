//
//  ZPFileViewerNavigationViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 10/29/12.
//
//

#import "ZPFileViewerNavigationViewController.h"

@interface ZPFileViewerNavigationViewController ()

@end

@implementation ZPFileViewerNavigationViewController

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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) toInterfaceOrientation{
    return YES;
}

@end
