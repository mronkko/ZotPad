//
//  ZPSplitViewController.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 8.4.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "ZPSplitViewController.h"
#import "ZPFileImportViewController.h"
#import "ZPUploadVersionConflictViewControllerViewController.h"


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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{

    if([segue.identifier isEqualToString:@"Import"]){
        NSURL* url = (NSURL*) sender;
        
        ZPFileImportViewController* target = segue.destinationViewController;
        target.url=url;
    }
    else if([segue.identifier isEqualToString:@"FileUploadConflict"]){
        ZPUploadVersionConflictViewControllerViewController* target = segue.destinationViewController;
        target.fileChannel = [(NSDictionary*) sender objectForKey:@"fileChannel"];
        target.attachment = [(NSDictionary*) sender objectForKey:@"attachment"];
    }
}

@end
