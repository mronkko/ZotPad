//
//  ZPDownloadAuthenticationDialogViewController.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 29.4.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZPFileChannel.h"

@interface ZPDownloadAuthenticationDialogViewController : UIViewController <UITableViewDataSource>{
}

@property (retain) UITextField* passwordField;
@property (retain) UITextField* usernameField;
@property (retain) IBOutlet UINavigationItem* navigationItem;
@property (retain) ZPFileChannel* caller;
@property (retain) NSString* hostname;

-(IBAction)cancel:(id)sender;
-(IBAction)login:(id)sender;

@end
