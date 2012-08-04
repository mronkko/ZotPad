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
#import "ZPItemListViewDataSource.h"

@class ZPItemListViewDataSource;

@interface ZPItemListViewController : UIViewController <UISplitViewControllerDelegate, UISearchBarDelegate, ZPItemObserver>{

    ZPItemListViewDataSource* _dataSource;
    DSBezelActivityView* _activityView;
    UITableView* _tableView;
    UIToolbar* _toolBar;
    NSInteger _tagForActiveSortButton;
    UIActivityIndicatorView* _activityIndicator;
    UIImageView* _sortDirectionArrow;
    CGPoint _offset;
}

@property (nonatomic, retain) IBOutlet UISearchBar* searchBar;
@property (nonatomic, retain) IBOutlet UIToolbar* toolBar;
@property (nonatomic, retain) IBOutlet UITableView* tableView;


@property (strong, nonatomic) UIPopoverController *masterPopoverController;

-(void)configureView;

- (void)makeBusy;
- (void)makeAvailable;

-(void)clearSearch;
-(void)doneSearchingClicked:(id) source;
-(IBAction) sortButtonPressed:(id)sender;
-(void) sortButtonLongPressed:(id)sender;
-(IBAction) attachmentThumbnailPressed:(id)sender;
@end
