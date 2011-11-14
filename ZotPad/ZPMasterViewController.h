//
//  ZPMasterViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ZPDetailViewController;

@interface ZPMasterViewController : UITableViewController

@property (strong, nonatomic) ZPDetailViewController *detailViewController;

@end
