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
    DSBezelActivityView* _activityView;
}

// This class is used as a singleton. 
// TODO: refactor the code so that this does not need a singleton
+ (ZPDetailedItemListViewController*) instance;

- (void)configureView;
- (void)clearTable;
- (void)configureCachedKeys:(NSArray*)array;
- (void)configureUncachedKeys:(NSArray*)uncachedItems;

- (void)makeBusy;
- (void)makeAvailable;

@property (nonatomic, retain) IBOutlet UISearchBar* searchBar;


-(void) clearSearch;
-(void) doOrderField:(NSString*)value;

-(IBAction)doSortCreator:(id)sender;
-(IBAction)doSortTitle:(id)sender;
-(IBAction)doSortDate:(id)sender;
-(IBAction)doSortPublication:(id)sender;

@end
