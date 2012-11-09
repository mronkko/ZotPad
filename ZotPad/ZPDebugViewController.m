//
//  ZPDebugViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 10/29/12.
//
//

#import "ZPDebugViewController.h"

@interface ZPDebugViewController ()

@end

@implementation ZPDebugViewController

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

- (void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
}

-(void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) toInterfaceOrientation{
    return YES;
}

/**
 * Called when an inset view controller will be shown, before the transition happens
 */
- (void)placeholderViewController:(HLSPlaceholderViewController *)placeholderViewController
      willShowInsetViewController:(UIViewController *)viewController
                         animated:(BOOL)animated{
    //NSLog(@"DEBUG");
}
/**
 * Called when an inset view controller will be shown, before the transition has ended
 */
- (void)placeholderViewController:(HLSPlaceholderViewController *)placeholderViewController
       didShowInsetViewController:(UIViewController *)viewController
                         animated:(BOOL)animated{
    //NSLog(@"DEBUG");

}
@end
