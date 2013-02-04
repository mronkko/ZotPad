//
//  ZPMasterItemListViewController.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 7/19/12.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPMasterItemListViewController.h"
#import "ZPItemList.h"

@interface ZPMasterItemListViewController ()

@end

@implementation ZPMasterItemListViewController

@synthesize detailViewController, itemListLoadingActivityView;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyItemListFullyLoaded:)
                                                 name:ZPNOTIFICATION_ITEM_LIST_FULLY_LOADED
                                               object:nil];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    itemListLoadingActivityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    itemListLoadingActivityView.hidesWhenStopped = TRUE;
    [itemListLoadingActivityView stopAnimating];
    
    UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:itemListLoadingActivityView];
    self.navigationItem.rightBarButtonItem = barButton;

    
    self.tableView.delegate = detailViewController;
    _dataSource = [[ZPItemListDataSource alloc] init];
    self.tableView.dataSource = _dataSource;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark - notifications

-(void) notifyItemListFullyLoaded:(NSNotification*) notification{
    [itemListLoadingActivityView stopAnimating];
}

@end
