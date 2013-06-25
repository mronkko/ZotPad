//
//  ZPNavigationViewController.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 6.7.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPNavigationController.h"
#import "ZPFileImportViewController.h"
#import "ZPUploadVersionConflictViewController.h"
#import "ZPFileViewerViewController.h"

@implementation ZPNavigationController

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_USER_INTERFACE_AVAILABLE object:nil];
}

-(IBAction)showLogView:(id)sender{
    [self performSegueWithIdentifier:@"ShowLogView" sender:NULL];
}

@end
