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

#import "ZPLogger.h"

@interface ZPDetailedItemListViewController (){
    ZPFileThumbnailAndQuicklookController* _buttonController;
}

- (void) _configureUncachedKeys:(NSArray*)itemKeyList;
- (void)_makeBusy;
- (void)_makeAvailable;
- (void) _configureCachedKeys;

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
    
    if([NSThread isMainThread]){
        
        // Update the user interface for the detail item.
        
        if (self.masterPopoverController != nil) {
            [self.masterPopoverController dismissPopoverAnimated:YES];
        }
        

        [self _makeAvailable];

        // Retrieve the item IDs if a library is selected. 
        
        if(_libraryID!=0){
            
            [_activityIndicator startAnimating];
            
            
            //This is required because a background thread might be modifying the table
             @synchronized(_tableView){
                 _itemKeysNotInCache = [NSMutableArray array];
                 _itemKeysShown = [NSArray array];
                 //TODO: Investigate why a relaodsection call a bit below causes a crash. Then uncomment these both.
                 //[_tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
                 [_tableView reloadData];
             }


            
            
            [self performSelectorInBackground:@selector(_configureCachedKeys) withObject:nil];
        }
    }
    else{
        [self performSelectorOnMainThread:@selector(configureView) withObject:NULL waitUntilDone:FALSE];
    }
}
//If we are not already displaying an activity view, do so now

- (void)_makeBusy{
    if(_activityView==NULL){
        [_tableView setUserInteractionEnabled:FALSE];
        _activityView = [DSBezelActivityView newActivityViewForView:_tableView];
    }
}

- (void) _configureCachedKeys{
    
    NSArray* array = [[ZPDataLayer instance] getItemKeysFromCacheForLibrary:self.libraryID collection:self.collectionKey
                                                                                                      searchString:[self.searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]orderField:self.orderField sortDescending:self.sortDescending];
    @synchronized(_tableView){
        _itemKeysShown = array;
        
        //TODO: Uncommenting thic causes the thread to crash. Investigate why. After this uncomment also the reload sections earlier.
        //[_tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
        [_tableView reloadData];
        
        //We do not need to observe for new item events if we do not have a list of unknown keys available
        [[ZPDataLayer instance] removeItemObserver:self];

    }
    
    //TODO: HIGH PRIORITY - MAKE THESE RUN IN AN NSOPERATION QUEUE THAT ONLY SUPPORTS A LIMITED NUMBER OF PARALLEL RETRIEVALS AND CANCELS
    
    // Queue an operation to retrieve all item keys that belong to this collection but are not found in cache. 
    [[ZPDataLayer instance] uncachedItemKeysForView:self];

    if([_itemKeysShown count] == 0){
        [self performSelectorOnMainThread:@selector(_makeBusy) withObject:NULL waitUntilDone:YES];
    }
    
}

/*
 Called from data layer to notify that there is data for this view and it can be shown
 */

- (void)_makeAvailable{
    [DSBezelActivityView removeViewAnimated:YES];

    [_tableView setUserInteractionEnabled:TRUE];
    _activityView = NULL;
}

- (void) configureUncachedKeys:(NSArray*)uncachedItems{
        
    //Only update the uncached keys if we are still showing the same item key list
    [_itemKeysNotInCache addObjectsFromArray:uncachedItems];
    if([_itemKeysShown count] ==0){
        [self _performTableUpdates];
        [self performSelectorOnMainThread:@selector(_makeAvailable) withObject:NULL waitUntilDone:YES];
    }
    else{
        [self _performTableUpdates];
        
    }
    [[ZPDataLayer instance] registerItemObserver:self];

    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

   
    //This array contains NSStrings and NSNulls. Nulls mean that there is no data available yet
    NSObject* keyObj = [_itemKeysShown objectAtIndex: indexPath.row];
    
    
    UITableViewCell* cell = [_cellCache objectForKey:keyObj];
    
    //TODO: Do not allocate any UI elements in this method, but specify them in the story board
    
    if(cell==nil){
        
        cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];

        
        if(keyObj != [NSNull null]){

            //If the cell contains an item, add publication details and thumbnail
            
            ZPZoteroItem* item=[ZPZoteroItem retrieveOrInitializeWithKey:(NSString*)keyObj];

            //Publication as a formatted label

            NSString* publishedIn = item.publishedIn;
            
            if(publishedIn == NULL){
                publishedIn=@"";   
            }
            
            //Does this cell already have a TTStyledTextLabel
            NSEnumerator* e = [[cell subviews] objectEnumerator];

            TTStyledTextLabel* publishedInLabel;

            NSObject* subView;
            while(subView = [e nextObject]){
                if([subView isKindOfClass:[TTStyledTextLabel class]]){
                    publishedInLabel = (TTStyledTextLabel*) subView;
                    break;
                }
            }
            //Get the authors label so that we can align publication details label with it
            UILabel *authorsLabel = (UILabel *)[cell viewWithTag:2];
            
            if(publishedInLabel == NULL){
                CGRect frame = CGRectMake(CGRectGetMinX(authorsLabel.frame),CGRectGetMaxY(authorsLabel.frame),CGRectGetWidth(cell.frame)-CGRectGetMinX(authorsLabel.frame),CGRectGetHeight(cell.frame)-CGRectGetMaxY(authorsLabel.frame)-2);
                publishedInLabel = [[TTStyledTextLabel alloc] 
                                            initWithFrame:frame];
                [publishedInLabel setFont:[UIFont systemFontOfSize:12]];
                [publishedInLabel setClipsToBounds:TRUE];
                [cell addSubview:publishedInLabel];
            }
            TTStyledText* text = [TTStyledText textFromXHTML:[publishedIn stringByReplacingOccurrencesOfString:@" & " 
                                                                                                    withString:@" &amp; "] lineBreaks:YES URLs:NO];
            [publishedInLabel setText:text];
            

            UIView* articleThumbnailHolder = (UIView *) [cell viewWithTag:4];

            //Remove all subviews
            for (UIView *view in  articleThumbnailHolder.subviews) {
                [view removeFromSuperview];
            }
            
             //Check if the item has attachments and render a thumbnail from the first attachment PDF
             
            if([item.attachments count] > 0){

                UIButton* button = [[UIButton alloc] init];
                [articleThumbnailHolder addSubview:button];
                button.frame = articleThumbnailHolder.frame;
                
                [_buttonController configureButton:button withAttachment:[item.attachments objectAtIndex:0]];
                
            }
        }
        [_cellCache setObject:cell forKey:keyObj];
    }
    
    return cell;
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
   
    [super viewDidLoad];
    
	// Do any additional setup after loading the view, typically from a nib.

    _instance = self;

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
    [self doOrderField:@"publishedIn"];
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
