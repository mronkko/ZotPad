//
//  ZPDetailViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "../DSActivityView/Sources/DSActivityView.h"
#import "ZPItemListViewController.h"
#import "ZPItemDetailViewController.h"

@interface ZPItemListViewController : UIViewController <UISplitViewControllerDelegate, UISearchBarDelegate, ZPItemObserver>{

    //This is an array instead of a mutable array because of thread safety
    NSArray* _itemKeysShown;
    NSMutableArray* _itemKeysNotInCache;
    
    NSString* _searchString;
    NSString* _collectionKey;
    NSNumber* _libraryID;
    NSString* _orderField;
    BOOL _sortDescending;
    
    DSBezelActivityView* _activityView;
    ZPItemDetailViewController* _itemDetailViewController;
    UITableView* _tableView;
    UITableView* _ownedTableView;
    UIToolbar* _toolBar;
    NSInteger _tagForActiveSortButton;
    UIActivityIndicatorView* _activityIndicator;
    NSInteger _animations;
    BOOL _hasContent;
    BOOL _invalidated;

}

@property (nonatomic, retain) IBOutlet UISearchBar* searchBar;
@property (nonatomic, retain) IBOutlet UIToolbar* toolBar;
@property (nonatomic, retain) IBOutlet UITableView* tableView;

//This is the tableview that the datasource targets.
@property (nonatomic, retain) UITableView* targetTableView;

@property (nonatomic, retain) ZPItemDetailViewController* itemDetailViewController;

@property (nonatomic, retain) NSArray* itemKeysShown;
@property (nonatomic, retain) NSString* collectionKey;
@property (nonatomic, retain) NSNumber* libraryID;
@property (nonatomic, retain) NSString* searchString;
@property (nonatomic, retain) NSString* orderField;
@property (assign) BOOL sortDescending;

- (void)configureView;
- (void)clearTable;
- (void)configureCachedKeys:(NSArray*)array;
- (void)configureUncachedKeys:(NSArray*)uncachedItems;

- (void)makeBusy;
- (void)makeAvailable;

-(void) clearSearch;
-(void) doneSearchingClicked:(id) source;
-(IBAction) sortButtonPressed:(id)sender;
-(void) sortButtonLongPressed:(id)sender;
-(IBAction) attachmentThumbnailPressed:(id)sender;
@end
