//
//  ZPQLPreviewControllerViewController.m
//  ZotPad
//
//  The purpose of this class is to block unnecessary features of QLPreviewController
//
//  Created by Rönkkö Mikko on 11/5/12.
//
//

#import "ZPQLPreviewControllerViewController.h"
#import "ZPFileViewerViewController.h"

@interface ZPQLPreviewControllerViewController () {
  
}
@end

@implementation ZPQLPreviewControllerViewController

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

-(void)viewWillDisappear:(BOOL)animated{
    
}
@end
