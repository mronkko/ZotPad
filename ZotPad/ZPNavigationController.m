//
//  ZPNavigationViewController.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 6.7.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPNavigationController.h"
#import "ZPFileImportViewController.h"
#import "ZPUploadVersionConflictViewControllerViewController.h"
#import "ZPFileViewerViewController.h"

@implementation ZPNavigationController

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    
    if([segue.identifier isEqualToString:@"Import"]){
        NSURL* url = (NSURL*) sender;
        
        ZPFileImportViewController* target = segue.destinationViewController;
        target.url=url;
    }
    else if([segue.identifier isEqualToString:@"FileUploadConflict"]){
        ZPUploadVersionConflictViewControllerViewController* target = segue.destinationViewController;
        target.fileChannel = [(NSDictionary*) sender objectForKey:@"fileChannel"];
        target.attachment = [(NSDictionary*) sender objectForKey:ZPKEY_ATTACHMENT];
    }
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_USER_INTERFACE_AVAILABLE object:nil];
}

-(IBAction)showLogView:(id)sender{
    [self performSegueWithIdentifier:@"ShowLogView" sender:NULL];
}

@end
