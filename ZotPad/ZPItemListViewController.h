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
#import "ZPItemListViewController.h"

//TODO: Make this a UITableViewController instead of UIViewController

@interface ZPItemListViewController : UITableViewController <UISplitViewControllerDelegate, UISearchBarDelegate>{
    NSString* _searchString;
    NSInteger _collectionID;
    NSInteger _libraryID;
    NSString* _sortField;
    BOOL _sortDescending;
    DSBezelActivityView* _activityView;
}

// This class is used as a singleton
+ (ZPItemListViewController*) instance;

- (void)configureView;
- (void)notifyDataAvailable;
- (void)notifyItemAvailable:(NSString*) key;
- (void)_refreshCellAtIndexPaths:(NSArray*)indexPath;
- (void)makeBusy;

@property (nonatomic, retain) IBOutlet UISearchBar* searchBar;

@property (retain) NSArray* itemKeysShown;

@property NSInteger collectionID;
@property NSInteger libraryID;

@property (copy) NSString* searchString;

@property (copy) NSString* sortField;
@property BOOL sortDescending;

-(void) clearSearch;

-(IBAction) sortButtonPressed:(id)sender;
-(void) sortButtonLongPressed:(id)sender;

@end
