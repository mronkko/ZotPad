//
//  ZPDetailViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//


#import "ZPDetailedItemListViewController.h"
#import "ZPLibraryAndCollectionListViewController.h"
#import "ZPDataLayer.h"
#import "../DSActivityView/Sources/DSActivityView.h"
#import "ZPFileThumbnailAndQuicklookController.h"
#import "ZPItemDetailViewController.h"

#import "ZPPreferences.h"

#import "ZPLogger.h"

//TODO: Refactor so that these would not be needed
#import "ZPServerConnection.h"
#import "ZPDatabase.h"
#import "ZPCacheController.h"


//A small helper class for performing configuration of uncanched items list in itemlistview

@interface ZPUncachedItemsOperation : NSOperation {
@private
    NSString*_searchString;
    NSString*_collectionKey;
    NSNumber* _libraryID;
    NSString* _orderField;
    BOOL _sortDescending;
    ZPDetailedItemListViewController* _itemListController;
}

-(id) initWithItemListController:(ZPDetailedItemListViewController*)itemListController;

@end

@implementation ZPUncachedItemsOperation;

-(id) initWithItemListController:(ZPDetailedItemListViewController*)itemListController{
    self = [super init];
    _itemListController=itemListController;
    _searchString = itemListController.searchString;
    _collectionKey = itemListController.collectionKey;
    _libraryID = itemListController.libraryID;
    _orderField = itemListController.orderField;
    _sortDescending = itemListController.sortDescending;
    
    return self;
}

-(void)main {
    
    if ( self.isCancelled ) return;
    NSLog(@"Clearing table");
    
    [_itemListController clearTable];
    NSLog(@"Retrieving cached keys");
    NSArray* cacheKeys= [[ZPDataLayer instance] getItemKeysFromCacheForLibrary:_libraryID collection:_collectionKey
                                                               searchString:_searchString orderField:_orderField sortDescending:_sortDescending];
    NSLog(@"Got cached keys");
    if ( self.isCancelled ) return;
    
    if([cacheKeys count]>0){
        NSLog(@"Configuring cached keys");

        [_itemListController configureCachedKeys:cacheKeys];
    }

    if(![[ZPPreferences instance] online]){
        [_itemListController configureUncachedKeys:[NSArray array]];
    }
    else{
        if ( self.isCancelled ) return;
        NSLog(@"Retrieving server keys");

        if([cacheKeys count]==0){
            NSLog(@"Making view busy");
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
                    NSLog(@"Deleted old items from library");

                }
                else{
                    [[ZPDatabase instance] removeItemKeysNotInArray:serverKeys fromCollection:_collectionKey];
                    [[ZPDatabase instance] addItemKeys:uncachedItems toCollection:_collectionKey];
                    NSLog(@"Refreshed collection memberships in cache");

                }
                
            }
        }

        if ( self.isCancelled ) return;
        
        //Add this into the queue if there are any uncached items
        if([uncachedItems count]>0){
            [[ZPCacheController instance] addToItemQueue:uncachedItems libraryID:_libraryID priority:YES];
            
            if(![_searchString isEqualToString:@""]){
                if(_collectionKey!=NULL && ! [_searchString isEqualToString:@""]) [[ZPCacheController instance] addToCollectionsQueue:[ZPZoteroCollection ZPZoteroCollectionWithKey:_collectionKey]  priority:YES];
                else [[ZPCacheController instance] addToLibrariesQueue:[ZPZoteroLibrary ZPZoteroLibraryWithID: _libraryID] priority:YES];
            }
        }

        if ( self.isCancelled ) return;
        NSLog(@"Setting server keys");

        [_itemListController configureUncachedKeys:uncachedItems];
    }
    
    
    
    
    
    
}
@end


@interface ZPDetailedItemListViewController (){
    ZPFileThumbnailAndQuicklookController* _buttonController;
    NSOperationQueue* _uiEventQueue;
}

@property (strong, nonatomic) UIPopoverController *masterPopoverController;

@end


@implementation ZPDetailedItemListViewController

@synthesize masterPopoverController = _masterPopoverController;

@synthesize searchBar;

static ZPDetailedItemListViewController* _instance = nil;

#pragma mark - Managing the detail item

-(id) init{
    self = [super init];
    return self;
}

+ (ZPDetailedItemListViewController*) instance{
    return _instance;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}


- (void)configureView
{
    //Clear item keys shown so that UI knows to stop drawing the old items
    _invalidated = TRUE;
    [[ZPDataLayer instance] removeItemObserver:self];

    if([NSThread isMainThread]){

        
        if (self.masterPopoverController != nil) {
            [self.masterPopoverController dismissPopoverAnimated:YES];
        }
        

        [self makeAvailable];

        // Retrieve the item IDs if a library is selected. 
        
        if(_libraryID!=0){
            
            if([[ZPPreferences instance] online]) [_activityIndicator startAnimating];
            
            
            //This queue is only used for retrieving key lists for uncahced items, so we can just invalidate all previous requests
            [_uiEventQueue cancelAllOperations];
            ZPUncachedItemsOperation* operation = [[ZPUncachedItemsOperation alloc] initWithItemListController:self];
            [_uiEventQueue addOperation:operation];
            NSLog(@"UI update events in queue %i",[_uiEventQueue operationCount]);

        }
    }
    else{
        [self performSelectorOnMainThread:@selector(configureView) withObject:NULL waitUntilDone:FALSE];
    }
}
//If we are not already displaying an activity view, do so now

- (void)makeBusy{
    if(_activityView==NULL){
        _activityView = [DSBezelActivityView newActivityViewForView:[_tableView superview] withLabel:@"Loading data from\nZotero server..."];
    }
}

/*
 Called from data layer to notify that there is data for this view and it can be shown
 */

- (void)makeAvailable{
    [DSBezelActivityView removeViewAnimated:YES];
    _activityView = NULL;
}

- (void)clearTable{
    
    _invalidated = TRUE;
    
    @synchronized(_tableView){
        
        BOOL needsReload = [self tableView:_tableView numberOfRowsInSection:0]>1;

        _itemKeysNotInCache = [NSMutableArray array];
        _itemKeysShown = [NSArray array];
        
        //We do not need to observe for new item events if we do not have a list of unknown keys available
        [[ZPDataLayer instance] removeItemObserver:self];
        
        //TODO: Investigate why a relaodsection call a bit below causes a crash. Then uncomment these both.
        //[_tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
        if(needsReload){
            [_tableView performSelectorOnMainThread:@selector(reloadData) withObject:NULL waitUntilDone:YES];
            NSLog(@"Reloaded data (1). Number of rows now %i",[self tableView:_tableView  numberOfRowsInSection:0]);
        }
    }
}

- (void) configureCachedKeys:(NSArray*)array{

    @synchronized(_tableView){

        _itemKeysShown = array;
        [_tableView performSelectorOnMainThread:@selector(reloadData) withObject:NULL waitUntilDone:YES];
        NSLog(@"Reloaded data (2). Number of rows now %i",[self tableView:_tableView  numberOfRowsInSection:0]);
        
    }
}


- (void) configureUncachedKeys:(NSArray*)uncachedItems{
        
    //Only update the uncached keys if we are still showing the same item key list
    _itemKeysNotInCache = [NSMutableArray arrayWithArray:uncachedItems];
    _invalidated = FALSE;
    [[ZPDataLayer instance] registerItemObserver:self];
    [self _performTableUpdates:FALSE];
    [self performSelectorOnMainThread:@selector(makeAvailable) withObject:NULL waitUntilDone:NO];
    NSLog(@"Configured uncached keys");

    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

   
    //If the data has become invalid, return a cell 
    NSArray* tempArray = _itemKeysShown;
    if(indexPath.row>=[tempArray count]){
        if(_libraryID==0) return [tableView dequeueReusableCellWithIdentifier:@"ChooseLibraryCell"];
        else if(_invalidated) return [tableView dequeueReusableCellWithIdentifier:@"BlankCell"];
        else return [tableView dequeueReusableCellWithIdentifier:@"NoItemsCell"];
    }
    
    NSObject* keyObj = [tempArray objectAtIndex: indexPath.row];
    
    
    UITableViewCell* cell = [_cellCache objectForKey:keyObj];
    
    
    if(cell==nil){
        
        cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];

        
        if(keyObj != [NSNull null]){

            //If the cell contains an item, add publication details and thumbnail
            
            ZPZoteroItem* item=[ZPZoteroItem retrieveOrInitializeWithKey:(NSString*)keyObj];

            //Publication as a formatted label

            
            TTStyledTextLabel* publicationTitleLabel = (TTStyledTextLabel*) [cell viewWithTag:3];

            if( item.publicationTitle == NULL){
                [publicationTitleLabel setHidden:TRUE];
            }
            else{
                [publicationTitleLabel setHidden:FALSE];
                
                //TODO: Could these two be configured in storyboard?
                
                [publicationTitleLabel setFont:[UIFont systemFontOfSize:12]];
                [publicationTitleLabel setClipsToBounds:TRUE];
                TTStyledText* text = [TTStyledText textFromXHTML:[item.publicationTitle stringByReplacingOccurrencesOfString:@" & " 
                                                                                                    withString:@" &amp; "] lineBreaks:YES URLs:NO];
                [publicationTitleLabel setText:text];
            }

            UIButton* articleThumbnail = (UIButton *) [cell viewWithTag:4];

             //Check if the item has attachments and render a thumbnail from the first attachment PDF
             
            if([item.attachments count] > 0){
                [articleThumbnail removeTarget:nil 
                                        action:NULL 
                              forControlEvents:UIControlEventAllEvents];

                [articleThumbnail setHidden:FALSE];
                [_buttonController configureButton:articleThumbnail withAttachment:[item.attachments objectAtIndex:0]];
                
            }
            else{
                [articleThumbnail setHidden:TRUE];
            }
        }
        [_cellCache setObject:cell forKey:keyObj];
    }
    
    return cell;
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    // Make sure your segue name in storyboard is the same as this line
    if ([[segue identifier] isEqualToString:@"PushItemDetailView"])
    {
        ZPItemDetailViewController* target = (ZPItemDetailViewController*)[segue destinationViewController];
        
        // Get the selected row from the item list
        NSIndexPath* indexPath = [_tableView indexPathForSelectedRow];
        
        // Get the key for the selected item 
        NSString* currentItemKey = [_itemKeysShown objectAtIndex: indexPath.row]; 
        [target setSelectedItem:[ZPZoteroItem retrieveOrInitializeWithKey:currentItemKey]];
        
        // Set the navigation controller
//        [[ZPLibraryAndCollectionListViewController instance] performSegueWithIdentifier:@"PushItemsToNavigator" sender:self];
        ZPSimpleItemListViewController* simpleItemListViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"NavigationItemListView"];
        simpleItemListViewController.navigationItem.hidesBackButton = YES;

        [simpleItemListViewController configureWithItemListController:[ZPDetailedItemListViewController instance]];
        [[[ZPLibraryAndCollectionListViewController instance] navigationController] pushViewController:simpleItemListViewController  animated:YES];

        [simpleItemListViewController.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionMiddle]; 
        [simpleItemListViewController.tableView setDelegate: target];
        
    }
    
}



#pragma mark - View lifecycle

- (void)viewDidLoad
{
   
    [super viewDidLoad];
    
	// Do any additional setup after loading the view, typically from a nib.

    _instance = self;

    _uiEventQueue = [[NSOperationQueue alloc] init];
    _uiEventQueue.maxConcurrentOperationCount = 3;

    // 64 X 64 is the smallest file type icon size on iPad 2
    _buttonController = [[ZPFileThumbnailAndQuicklookController alloc]
                         initWithItem:NULL viewController:self maxHeight:64
                         maxWidth:64];


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

#pragma mark - Actions

-(void) doOrderField:(NSString*)value{
    if([value isEqualToString: _orderField ]){
        _sortDescending = !_sortDescending;
    }
    else{
        _orderField = value;
        _sortDescending = FALSE;
    }
    
    [self configureView];
}

-(IBAction)doSortCreator:(id)sender{
    [self doOrderField:@"creator"];
}

-(IBAction)doSortDate:(id)sender{
    [self doOrderField:@"year"];
}

-(IBAction)doSortTitle:(id)sender{
    [self doOrderField:@"title"];
}

-(IBAction)doSortPublication:(id)sender{
    [self doOrderField:@"publicationTitle"];
}

-(void) clearSearch{
    _searchString = NULL;
    [searchBar setText:@""];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sourceSearchBar{
    
    if(![[sourceSearchBar text] isEqualToString:_searchString]){
        _searchString = [[sourceSearchBar text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [self configureView];
    }
    [sourceSearchBar resignFirstResponder ];
}

@end
