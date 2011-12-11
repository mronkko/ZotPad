//
//  ZPNavigationItemListViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/4/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//


#import <UIKit/UIKit.h>
#import "ZPItemObserver.h"

// This class does not inherit UITableViewController because we want to be able to 
// have the table view as a subview instead of main view so that search bar and tool bar can be
// added in the top and bottom of the list

@interface ZPSimpleItemListViewController : UIViewController <UITableViewDataSource, ZPItemObserver>{
    NSCache* _cellCache;
    NSArray* _itemKeysShown;
    UITableView* _tableView;
}

@property (retain) IBOutlet UITableView* tableView;
@property (retain) NSArray* itemKeysShown;

- (void)_refreshCellAtIndexPaths:(NSArray*)indexPath;

@end
