//
//  ZPNewTagViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/4/12.
//
//

#import "ZPNewTagViewController.h"

@interface ZPNewTagViewController ()

@end

@implementation ZPNewTagViewController

@synthesize parent, textField;

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
    [self.textField becomeFirstResponder];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)createTag:(id)sender{
    
}
@end
