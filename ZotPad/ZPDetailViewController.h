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

@interface ZPDetailViewController : UIViewController <UISplitViewControllerDelegate, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>{
    NSString* _searchString;
    NSInteger _collectionID;
    NSInteger _libraryID;
    NSString* _sortField;
    BOOL _sortDescending;
    
    NSArray* _itemKeysShown;
  
    UITableView* itemTableView;
    NSCache* _cellCache;
    DSBezelActivityView* _activityView;
}

// This class is used as a singleton
+ (ZPDetailViewController*) instance;

- (void)configureView;
- (void)notifyDataAvailable;
- (void)notifyItemAvailable:(NSString*) key;
- (void)_refreshCellAtIndexPaths:(NSArray*)indexPath;


@property (nonatomic, retain) IBOutlet UITableView* itemTableView;
@property (nonatomic, retain) IBOutlet UISearchBar* searchBar;

@property (retain) NSArray* itemKeysShown;

@property NSInteger collectionID;
@property NSInteger libraryID;

@property (copy) NSString* searchString;

@property (copy) NSString* sortField;
@property BOOL sortDescending;

-(void) clearSearch;

-(void) doSortField:(NSString*)value;

-(IBAction)doSortCreator:(id)sender;
-(IBAction)doSortTitle:(id)sender;
-(IBAction)doSortDate:(id)sender;
-(IBAction)doSortPublication:(id)sender;

@end
