//
//  ZPMasterViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZPItemListViewController.h"
#import "ZPDataLayer.h"

@class ZPItemListViewController;

@interface ZPLibraryAndCollectionListViewController : UITableViewController{
    ZPDataLayer* _database;
    NSArray* _content;
    NSInteger _currentLibrary;
    NSInteger _currentCollection;
    UITableView* navigationTableView;
}
@property (strong, nonatomic) ZPItemListViewController *detailViewController;
@property NSInteger currentLibrary;
@property NSInteger currentCollection;

@property (nonatomic, retain) IBOutlet UITableView* navigationTableView;

+ (ZPLibraryAndCollectionListViewController*) instance;
- (void)notifyDataAvailable;

@end
