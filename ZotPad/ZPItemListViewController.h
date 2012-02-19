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
#import "ZPItemDetailViewController.h"


@interface ZPItemListViewController : UITableViewController <UISplitViewControllerDelegate, UISearchBarDelegate>{
    NSString* _searchString;
    NSString* _collectionKey;
    NSNumber* _libraryID;
    NSString* _sortField;
    BOOL _sortDescending;
    DSBezelActivityView* _activityView;
    NSCache* _cellCache;
}

- (void)configureView;
- (void)notifyDataAvailable;
- (void)notifyItemAvailable:(NSString*) key;
- (void)_refreshCellAtIndexPaths:(NSArray*)indexPath;
- (void)makeBusy;

@property (nonatomic, retain) IBOutlet UISearchBar* searchBar;
@property (strong, nonatomic) ZPItemDetailViewController* detailViewController;
@property (assign, nonatomic) BOOL masterIsVisible;

@property (nonatomic, retain) NSArray* itemKeysShown;
@property (nonatomic, retain) NSString* collectionKey;
@property (nonatomic, retain) NSNumber* libraryID;
@property (nonatomic, retain) NSString* searchString;
@property (nonatomic, retain) NSString* sortField;
@property BOOL sortDescending;

-(void) clearSearch;

-(IBAction) sortButtonPressed:(id)sender;
-(void) sortButtonLongPressed:(id)sender;

@end
