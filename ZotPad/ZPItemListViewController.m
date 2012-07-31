//
//  ZPDetailViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "ZPItemListViewController.h"
#import "ZPDataLayer.h"
#import "DSActivityView.h"
#import "ZPLocalization.h"
#import "ZPPreferences.h"
#import "ZPAppDelegate.h"

//TODO: Refactor so that these would not be needed
#import "ZPServerConnection.h"
#import "ZPDatabase.h"
#import "ZPCacheController.h"


//A small helper class for performing configuration of uncanched items list in itemlistview

//TODO: Refactor this away

#pragma mark - Helper class for requesting item data from the server

@interface ZPUncachedItemsOperation : NSOperation {
@private
    NSString*_searchString;
    NSString*_collectionKey;
    NSNumber* _libraryID;
    NSString* _orderField;
    BOOL _sortDescending;
    ZPItemListViewDataSource* _itemListDataSource;
    ZPItemListViewController* _itemListController;
}

-(id) initWithItemListController:(ZPItemListViewDataSource*)itemListController dataSource:(ZPItemListViewDataSource*) dataSource ;

@end

@implementation ZPUncachedItemsOperation;

-(id) initWithItemListController:(ZPItemListViewDataSource*)itemListController dataSource:(ZPItemListViewDataSource *)dataSource{
    self = [super init];
    _itemListDataSource = dataSource;
    _itemListController=itemListController;
    _searchString = dataSource.searchString;
    _collectionKey = dataSource.collectionKey;
    _libraryID = dataSource.libraryID;
    _orderField = dataSource.orderField;
    _sortDescending = dataSource.sortDescending;
    
    return self;
}

-(void)main {
    
    if ( self.isCancelled ) return;
    //DDLogVerbose(@"Clearing table");
    
    [_itemListDataSource clearTable];
    //DDLogVerbose(@"Retrieving cached keys");
    NSArray* cacheKeys= [[ZPDataLayer instance] getItemKeysFromCacheForLibrary:_libraryID collection:_collectionKey
                                                                  searchString:_searchString orderField:_orderField sortDescending:_sortDescending];
    //DDLogVerbose(@"Got cached keys");
    if ( self.isCancelled ) return;
    
    if([cacheKeys count]>0){
        //DDLogVerbose(@"Configuring cached keys");
        
        [_itemListDataSource configureCachedKeys:cacheKeys];
    }
    
    if(![[ZPPreferences instance] online]){
        [_itemListDataSource configureUncachedKeys:[NSArray array]];
    }
    else{
        if ( self.isCancelled ) return;
        //DDLogVerbose(@"Retrieving server keys");
        
        if([cacheKeys count]==0){
            //DDLogVerbose(@"Making view busy");
            [_itemListController performSelectorOnMainThread:@selector(makeBusy) withObject:NULL waitUntilDone:FALSE];        
        }
        NSArray* serverKeys =[[ZPServerConnection instance] retrieveKeysInContainer:_libraryID collectionKey:_collectionKey searchString:_searchString orderField:_orderField sortDescending:_sortDescending];
        
        NSMutableArray* uncachedItems = [NSMutableArray arrayWithArray:serverKeys];
        [uncachedItems removeObjectsInArray:cacheKeys];
        
        //Check if the collection memberships are still valid in the cache
        if(_searchString == NULL || [_searchString isEqualToString:@""]){
            if([serverKeys count]!=[cacheKeys count] || [uncachedItems count] > 0){
                if(_collectionKey == NULL){
                    [[ZPDatabase instance] deleteItemKeysNotInArray:serverKeys fromLibrary:_libraryID];
                    //DDLogVerbose(@"Deleted old items from library");
                    
                }
                else{
                    [[ZPDatabase instance] removeItemKeysNotInArray:serverKeys fromCollection:_collectionKey];
                    [[ZPDatabase instance] addItemKeys:uncachedItems toCollection:_collectionKey];
                    //DDLogVerbose(@"Refreshed collection memberships in cache");
                    
                }
                
            }
        }
        
        if ( self.isCancelled ) return;
        
        //Add this into the queue if there are any uncached items
        if([uncachedItems count]>0){
            [[ZPCacheController instance] addToItemQueue:uncachedItems libraryID:_libraryID priority:YES];
            
            if(![_searchString isEqualToString:@""]){
                if(_collectionKey!=NULL && ! [_searchString isEqualToString:@""]) [[ZPCacheController instance] addToCollectionsQueue:(ZPZoteroCollection*)[ZPZoteroCollection dataObjectWithKey:_collectionKey]  priority:YES];
                else [[ZPCacheController instance] addToLibrariesQueue:(ZPZoteroLibrary*)[ZPZoteroLibrary dataObjectWithKey: _libraryID] priority:YES];
            }
        }
        
        if ( self.isCancelled ) return;
        //DDLogVerbose(@"Setting server keys");
        
        [_itemListDataSource configureUncachedKeys:uncachedItems];
        [_itemListController performSelectorOnMainThread:@selector(makeAvailable) withObject:NULL waitUntilDone:FALSE];        
    }
    
}
@end



//A helped class for setting sort buttons

#pragma mark - Helper class for configuring sort buttons

@interface ZPItemListViewController_sortHelper: UITableViewController{
    NSArray* _fieldTitles;
    NSArray* _fieldValues;
}

@property (retain) UIPopoverController* popover;
@property (retain) UIButton* targetButton;


@end

@implementation ZPItemListViewController_sortHelper

@synthesize popover, targetButton;

-(id) init{
    self=[super init];
    
    NSMutableArray* fieldTitles = [NSMutableArray array];
    NSArray* fieldValues = [[ZPDataLayer instance] fieldsThatCanBeUsedForSorting];
    
    for(NSString* value in fieldValues){
        [fieldTitles addObject:[ZPLocalization getLocalizationStringWithKey:value type:@"field"]];
    }
    
    _fieldTitles = [fieldTitles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    NSMutableArray* sortedFieldValues = [NSMutableArray array];
    
    for(NSString* title in _fieldTitles){
        [sortedFieldValues addObject:[fieldValues objectAtIndex:[fieldTitles indexOfObjectIdenticalTo:title]]];
    }
    
    _fieldValues = sortedFieldValues;
    
    self.navigationItem.title = @"Choose sort field";
    self.tableView.delegate =self;
    self.tableView.dataSource =self;

    return self;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell* cell = [[UITableViewCell alloc] init];
    cell.textLabel.text = [_fieldTitles objectAtIndex:indexPath.row];

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [_fieldValues count];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    NSString* orderField = [_fieldValues objectAtIndex:indexPath.row];
    //Because this preference is not used anywhere else, it is accessed directly.
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:orderField forKey:[NSString stringWithFormat: @"itemListView_sortButton%i",self.targetButton.tag]];

    UILabel* label = (UILabel*)[self.targetButton.subviews lastObject];
    
    [label setText:[ZPLocalization getLocalizationStringWithKey:orderField type:@"field"]];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [self.popover dismissPopoverAnimated:YES];
    }
    else{
        [self dismissModalViewControllerAnimated:YES];
    }
}

@end


#pragma mark - Start of main class

@interface ZPItemListViewController (){
    NSOperationQueue* _uiEventQueue;
    ZPItemListViewController_sortHelper* _sortHelper;
    UIView* _overlay;
}

-(void) _configureSortButton:(UIButton*)button;

@end

@implementation ZPItemListViewController



@synthesize masterPopoverController = _masterPopoverController;

@synthesize tableView = _tableView;
@synthesize searchBar = _searchBar;
@synthesize toolBar = _toolBar;

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - Methods for configuring the view

- (void)configureView
{
    //Clear item keys shown so that UI knows to stop drawing the old items

    if(_dataSource.libraryID!=0){

        if([NSThread isMainThread]){
            
            _dataSource.targetTableView = self.tableView;
            //Set the navigation item
            
            if(_dataSource.collectionKey != NULL){
                ZPZoteroCollection* currentCollection = [ZPZoteroCollection dataObjectWithKey:_dataSource.collectionKey];
                self.navigationItem.title = currentCollection.title;
            }
            else {
                ZPZoteroLibrary* currentLibrary = [ZPZoteroLibrary dataObjectWithKey:_dataSource.libraryID];
                self.navigationItem.title = currentLibrary.title;
            }

            if (self.masterPopoverController != nil) {
                [self.masterPopoverController dismissPopoverAnimated:YES];
            }
            
            [self makeAvailable];
            
            // Retrieve the item IDs if a library is selected. 
            
            
            if([[ZPPreferences instance] online]) [_activityIndicator startAnimating];
            
            
            //This queue is only used for retrieving key lists for uncahced items, so we can just invalidate all previous requests
            [_uiEventQueue cancelAllOperations];
            ZPUncachedItemsOperation* operation = [[ZPUncachedItemsOperation alloc] initWithItemListController:self dataSource:_dataSource];
            [_uiEventQueue addOperation:operation];
            //DDLogVerbose(@"UI update events in queue %i",[_uiEventQueue operationCount]);
            
        }
        else{
            [self performSelectorOnMainThread:@selector(configureView) withObject:NULL waitUntilDone:FALSE];
        }

    }
}


//If we are not already displaying an activity view, do so now

- (void)makeBusy{
    if(_activityView==NULL){
        if([NSThread isMainThread]){
            [self.tableView setUserInteractionEnabled:FALSE];
            _activityView = [DSBezelActivityView newActivityViewForView:self.tableView];
        }
        else{
            [self performSelectorOnMainThread:@selector(makeBusy) withObject:nil waitUntilDone:NO];
        }   
    }
}


- (void)makeAvailable{
    if(_activityView!=NULL){
        if([NSThread isMainThread]){
            [DSBezelActivityView removeViewAnimated:YES];
            _activityView = NULL;
            [self.tableView setUserInteractionEnabled:TRUE];
        }
        else{
            [self performSelectorOnMainThread:@selector(makeAvailable) withObject:nil waitUntilDone:NO];
        }   
    }
    
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    // Make sure your segue name in storyboard is the same as this line
    if ([[segue identifier] isEqualToString:@"PushItemDetailView"])
    {
        ZPItemDetailViewController* itemDetailViewController = ( ZPItemDetailViewController*)[segue destinationViewController];
        
        // Get the selected row from the item list
        NSIndexPath* indexPath = [_tableView indexPathForSelectedRow];
        
        // Get the key for the selected item 
        NSString* currentItemKey = [_dataSource.itemKeysShown objectAtIndex: indexPath.row]; 
        [itemDetailViewController setSelectedItem:(ZPZoteroItem*)[ZPZoteroItem dataObjectWithKey:currentItemKey]];
        [itemDetailViewController configure];
        
        // Set the navigation controller in iPad
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
             
            ZPAppDelegate* appDelegate = (ZPAppDelegate*)[[UIApplication sharedApplication] delegate];
            
            UINavigationController* navigationController = [[(UISplitViewController*)appDelegate.window.rootViewController viewControllers] objectAtIndex:0];
            
            [navigationController.topViewController performSegueWithIdentifier:@"PushItemsToNavigator" sender:itemDetailViewController];

        }
        
    }
    
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{

    DDLogInfo(@"Loading item list in the content area");

    [super viewDidLoad];
    
    _dataSource = [ZPItemListViewDataSource instance];
    _tableView.dataSource = _dataSource;

    
    // Do any additional setup after loading the view, typically from a nib.
    	
	//  update the last update date
	// [_refreshHeaderView refreshLastUpdatedDate];

    
    //Configure objects
    
    _uiEventQueue =[[NSOperationQueue alloc] init];
    [_uiEventQueue setMaxConcurrentOperationCount:3];

    
    
    //Set up activity indicator. 

    _activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0,0,20, 20)];
    [_activityIndicator hidesWhenStopped];
    UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
    self.navigationItem.rightBarButtonItem = barButton;
    

    //Configure the sort buttons based on preferences
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    UIBarButtonItem* spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];  
    NSMutableArray* toobarItems=[NSMutableArray arrayWithObject:spacer];

    NSInteger buttonCount;

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) buttonCount = 6;
    else buttonCount = 3;
    
    for(NSInteger i = 1; i<=buttonCount; ++i){
        //Because this preference is not used anywhere else, it is accessed directly.
        NSString* orderField =  [defaults objectForKey:[NSString stringWithFormat: @"itemListView_sortButton%i",i]];
        NSString* title;
        if(orderField != NULL){
            title = [ZPLocalization getLocalizationStringWithKey:orderField type:@"field"];
        }
        else if(i<5){
            if(i==1) orderField =  @"title";
            else if(i==2) orderField =  @"creator";
            else if(i==3) orderField =  @"date";
            else if(i==4) orderField =  @"dateModified";
            
            [defaults setObject:orderField forKey:[NSString stringWithFormat: @"itemListView_sortButton%i",i]];
            title = [ZPLocalization getLocalizationStringWithKey:orderField type:@"field"];

        }
        else{
            title = @"Tap and hold to set";
        }
        
        UIButton* button  = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(0,0, 101, 30);
        [button setImage:[UIImage imageNamed:@"barbutton_image_up_state.png"] forState:UIControlStateNormal];
        [button setImage:[UIImage imageNamed:@"barbutton_image_down_state.png"] forState:UIControlStateHighlighted];

        
        UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(0,0, 90, 30)];
        
        label.textAlignment = UITextAlignmentCenter;
        label.adjustsFontSizeToFitWidth = YES;
        label.text = title;
        label.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor whiteColor];
        label.center = button.center;
        label.font =  [UIFont fontWithName:@"Helvetica" size:12.0f];
        
        [button addSubview:label];
        
        [button addTarget:self action:@selector(sortButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        button.tag = i;
        
        UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(sortButtonLongPressed:)];
        [button addGestureRecognizer:longPressRecognizer]; 

        UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:button];
        barButton.tag=i;

        [toobarItems addObject:barButton];
        [toobarItems addObject:spacer];


    }
    [_toolBar setItems:toobarItems];
    
    _tagForActiveSortButton = -1;
    [self configureView];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    /*
     
    TODO:
     
    @synchronized(_itemKeysNotInCache){
        //If there are more items coming, make this active
        if([_itemKeysNotInCache count] >0){
            [_activityIndicator startAnimating];
        }
        else{
            [_activityIndicator stopAnimating];
        }
    }
     */
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Libraries", @"Libraries");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

//Needed to keep the master right size http://stackoverflow.com/questions/9649608/uisplitview-new-slide-in-popover-becomes-fullscreen-after-memory-warning-in-ios

-(void)splitViewController:(UISplitViewController *)svc popoverController:(UIPopoverController *)pc willPresentViewController:(UIViewController *)aViewController
{
    aViewController.view.frame = CGRectMake(0, 0, 320, self.view.frame.size.height);
}

#pragma mark - Actions

-(IBAction) sortButtonPressed:(id)sender{

    
    if(_sortHelper!=NULL && [_sortHelper.popover isPopoverVisible]) [_sortHelper.popover dismissPopoverAnimated:YES];
    
    //Because this preference is not used anywhere else, it is accessed directly.
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* orderField =  [defaults objectForKey:[NSString stringWithFormat: @"itemListView_sortButton%i",[sender tag]]];
    if(orderField == NULL){
        [self _configureSortButton:sender];
    }
        
    else{
        NSInteger tag = [(UIView*)sender tag];
        if(_tagForActiveSortButton == tag){
            _dataSource.sortDescending  = ! _dataSource.sortDescending;
        }
        else{

            _tagForActiveSortButton = tag;

            if(_sortDirectionArrow!=NULL){
                [_sortDirectionArrow removeFromSuperview];
            }
            else {
                _sortDirectionArrow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"icon-up-black.png"]];
                _sortDirectionArrow.alpha = 0.25f;
            }
            
            [(UIButton*)sender insertSubview:_sortDirectionArrow atIndex:1];
            CGRect bounds = [(UIButton*)sender bounds];
            _sortDirectionArrow.center = CGPointMake(bounds.size.width / 2, bounds.size.height / 2);
            
            _dataSource.orderField = orderField;
            _dataSource.sortDescending = FALSE;
        }

        //TODO: consider storing the images
        _sortDirectionArrow.image = [UIImage imageNamed:(_dataSource.sortDescending ? @"icon-down-black.png":@"icon-up-black.png")];

        [self configureView];
    }

}


-(void) sortButtonLongPressed:(UILongPressGestureRecognizer*)sender{
    
    if(sender.state == UIGestureRecognizerStateBegan ){
        [self _configureSortButton:(UIButton*)[sender view]];
    }
}


-(void) _configureSortButton:(UIButton*)sender{
    
    UIBarButtonItem* button;
    for(button in _toolBar.items){
        if(button.tag == sender.tag) break;
    }
    
    if(_sortHelper == NULL){
        _sortHelper = [[ZPItemListViewController_sortHelper alloc] init]; 
        //TODO: iPhone support
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            _sortHelper.popover = [[UIPopoverController alloc] initWithContentViewController:_sortHelper];
        }
            
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        if([_sortHelper.popover isPopoverVisible]) [_sortHelper.popover dismissPopoverAnimated:YES];
    }
    _sortHelper.targetButton = (UIButton*) button.customView;

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [_sortHelper.popover presentPopoverFromBarButtonItem:button permittedArrowDirections: UIPopoverArrowDirectionAny animated:YES];
    }
    else{
        UINavigationController* controller = [[UINavigationController alloc] init];
        controller.viewControllers=[NSArray arrayWithObject:_sortHelper];
        [self presentModalViewController:controller animated:YES];
    }
}




-(void) clearSearch{
    _dataSource.searchString = NULL;
    [_searchBar setText:@""];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sourceSearchBar{
    
    [self doneSearchingClicked:NULL];
    
    if(![[sourceSearchBar text] isEqualToString:_dataSource.searchString]){
        _dataSource.searchString = [sourceSearchBar text];
        [self configureView];
    }
}

- (void) searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar {

    CGRect frame = _tableView.bounds;
    _overlay = [[UIView alloc] initWithFrame:frame];
    _overlay.backgroundColor = [UIColor grayColor];
    _overlay.alpha = 0.5;
    _overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    _tableView.scrollEnabled = NO;

    [_tableView addSubview:_overlay];

    //Add the done button.
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                               initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                               target:self action:@selector(doneSearchingClicked:)];
}
- (void) doneSearchingClicked:(id) source{
    self.navigationItem.rightBarButtonItem = NULL;
    [self.searchBar resignFirstResponder];
    [_overlay removeFromSuperview];
    _tableView.scrollEnabled = TRUE;
}
@end
