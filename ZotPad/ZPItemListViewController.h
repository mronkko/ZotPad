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
#import "ZPItemListDataSource.h"

@class ZPItemList;

@interface ZPItemListViewController : UIViewController <UISplitViewControllerDelegate, UISearchBarDelegate>{

    DSBezelActivityView* _activityView;
    UITableView* _tableView;
    UIToolbar* _toolBar;
    NSInteger _tagForActiveSortButton;
    UIImageView* _sortDirectionArrow;
    CGPoint _offset;
    
    ZPItemListDataSource* _dataSource;
}

@property (nonatomic, retain) IBOutlet UISearchBar* searchBar;
@property (nonatomic, retain) IBOutlet UIToolbar* toolBar;
@property (nonatomic, retain) IBOutlet UITableView* tableView;
@property (retain) UIActivityIndicatorView* itemListLoadingActivityView;


@property (strong, nonatomic) UIPopoverController *masterPopoverController;

-(void)configureView;
-(void)processItemListAvailableNotification:(NSDictionary*)content;
-(void)makeBusy;
-(void)makeAvailable;

-(void)clearSearch;
-(void)doneSearchingClicked:(id) source;
-(IBAction) sortButtonPressed:(id)sender;
-(void) sortButtonLongPressed:(id)sender;

// Notifications
-(void) notifyLibraryWithCollectionsAvailable:(NSNotification*) notification;
-(void) notifyAttachmentAvailable:(NSNotification*) notification;
-(void) notifyAttachmentDownloadFinished:(NSNotification*) notification;
-(void) notifyAttachmentDeleted:(NSNotification*) notification;

@end
