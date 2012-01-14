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
    
    //This is an array instead of a mutable array because of thread safety
    NSArray* _itemKeysShown;
    NSMutableArray* _itemKeysNotInCache;

    UITableView* _tableView;
    NSString*_searchString;
    NSString*_collectionKey;
    NSNumber* _libraryID;
    NSString* _orderField;
    BOOL _sortDescending;
    UIActivityIndicatorView* _activityIndicator;
    NSInteger _animations;
}

- (void)configureWithItemListController:(ZPSimpleItemListViewController*)controller;

// Needed by sub class, so needs to be here
- (void) _performTableUpdates;

@property (nonatomic, retain) IBOutlet UITableView* tableView;
@property (nonatomic, retain) NSArray* itemKeysShown;

@property (nonatomic, retain) NSString* collectionKey;
@property (nonatomic, retain) NSNumber* libraryID;
@property (nonatomic, retain) NSString* searchString;
@property (nonatomic, retain) NSString* orderField;
@property BOOL sortDescending;

@end
