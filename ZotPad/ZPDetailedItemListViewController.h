//
//  ZPDetailViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "../DSActivityView/Sources/DSActivityView.h"
#import "Three20/Three20.h"
#import "ZPSimpleItemListViewController.h"

//TODO: Make this a UITableViewController instead of UIViewController

@interface ZPDetailedItemListViewController : ZPSimpleItemListViewController <UISplitViewControllerDelegate, UISearchBarDelegate>{
    NSString* _searchString;
    NSString* _collectionKey;
    NSInteger _libraryID;
    NSString* _OrderField;
    BOOL _sortDescending;
    
    DSBezelActivityView* _activityView;
}

// This class is used as a singleton
+ (ZPDetailedItemListViewController*) instance;

- (void)configureView;
- (void)_refreshCellAtIndexPaths:(NSArray*)indexPath;

// The first of these makes the view busy and the second tells that it has data, so that it can become active again.

- (void)makeBusy;
- (void)notifyDataAvailable;

@property (nonatomic, retain) IBOutlet UISearchBar* searchBar;

@property (nonatomic, retain) NSString* collectionKey;

@property NSInteger libraryID;

@property (copy) NSString* searchString;

@property (copy) NSString* OrderField;
@property BOOL sortDescending;

-(void) clearSearch;

-(void) doOrderField:(NSString*)value;

-(IBAction)doSortCreator:(id)sender;
-(IBAction)doSortTitle:(id)sender;
-(IBAction)doSortDate:(id)sender;
-(IBAction)doSortPublication:(id)sender;

@end
