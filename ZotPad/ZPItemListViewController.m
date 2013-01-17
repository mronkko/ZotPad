//
//  ZPDetailViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "ZPItemListViewController.h"

#import "DSActivityView.h"
#import "ZPLocalization.h"

#import "ZPAppDelegate.h"
#import "ZPReachability.h"
#import "ZPServerConnection.h"

#import "ZPItemList.h"

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
    NSArray* fieldValues = [ZPDatabase fieldsThatCanBeUsedForSorting];
    
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
    ZPItemListViewController_sortHelper* _sortHelper;
    UIView* _overlay;
    BOOL _waitingForData;
}

-(void) _configureSortButton:(UIButton*)button;
-(void) _configureSortArrow;

@end

@implementation ZPItemListViewController



@synthesize masterPopoverController = _masterPopoverController;

@synthesize tableView = _tableView;
@synthesize searchBar = _searchBar;
@synthesize toolBar = _toolBar;

- (id) initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    
    //Register notifications
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(processItemListAvailableNotification:)
                                                 name:ZPNOTIFICATION_ITEM_LIST_AVAILABLE
                                               object:nil];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyAttachmentAvailable:)
                                                 name:ZPNOTIFICATION_ATTACHMENTS_AVAILABLE
                                               object:nil];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyAttachmentDownloadFinished:)
                                                 name:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FINISHED
                                               object:nil];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyAttachmentDeleted:)
                                                 name:ZPNOTIFICATION_ATTACHMENT_FILE_DELETED
                                               object:nil];
    
    return self;
    
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - Methods for configuring the view

- (void)configureView
{
    if(! [NSThread isMainThread]) [NSException raise:@"configureView must be called in main thread" format:@"configureView must be called in main thread"];
    
    //If the library ID is not set, set it to the first library
    if([ZPItemList instance].libraryID==LIBRARY_ID_NOT_SET){
        NSArray* libraries = [ZPDatabase libraries];
        if([libraries count]>0){
            NSInteger libraryID = [(ZPZoteroLibrary*) [libraries objectAtIndex:0] libraryID];
            [ZPItemList instance].libraryID = libraryID;
            
            [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ACTIVE_LIBRARY_CHANGED
                                                                object:[NSNumber numberWithInt:libraryID]];
            
        }
    }
    
    //Clear item keys shown so that UI knows to stop drawing the old items
    
    if([ZPItemList instance].libraryID!=LIBRARY_ID_NOT_SET){
        
        //Set the data source to target this view
        
        [ZPItemList instance].targetTableView = self.tableView;
        
        //Set the navigation item
        
        if([ZPItemList instance].collectionKey != NULL){
            ZPZoteroCollection* currentCollection = [ZPZoteroCollection collectionWithKey:[ZPItemList instance].collectionKey];
            self.navigationItem.title = currentCollection.title;
        }
        else {
            ZPZoteroLibrary* currentLibrary = [ZPZoteroLibrary libraryWithID:[ZPItemList instance].libraryID];
            self.navigationItem.title = currentLibrary.title;
        }
        
        // Hide the side panel that might be visible if iPad is in portrait orientation
        
        if (self.masterPopoverController != nil) {
            [self.masterPopoverController dismissPopoverAnimated:YES];
        }
        
        // Configuring the item list content starts here.
        
        
        if([ZPReachability hasInternetConnection]){
            
            [_activityIndicator startAnimating];
            
            [ZPServerConnection retrieveKeysInLibrary:[ZPItemList instance].libraryID
                                           collection:[ZPItemList instance].collectionKey
                                         searchString:[ZPItemList instance].searchString
                                                 tags:[ZPItemList instance].tags
                                           orderField:[ZPItemList instance].orderField
                                       sortDescending:[ZPItemList instance].sortDescending];
            
            [[ZPItemList instance] configureServerKeys:[NSArray array]];
            _waitingForData = TRUE;
        }
        
        // Configure the data source with content from the cache
        
        [[ZPItemList instance] clearTable];
        NSArray* cacheKeys= [ZPDatabase getItemKeysForLibrary:[ZPItemList instance].libraryID
                                                collectionKey:[ZPItemList instance].collectionKey
                                                 searchString:[ZPItemList instance].searchString
                                                         tags:[ZPItemList instance].tags
                                                   orderField:[ZPItemList instance].orderField
                                               sortDescending:[ZPItemList instance].sortDescending];
        
        
        [[ZPItemList instance] configureCachedKeys:cacheKeys];
        
        
        //If there is nothing to display, make the view busy until we receive something from the server.
        
        if([ZPReachability hasInternetConnection] && [cacheKeys count]==0) [self makeBusy];
        else [self makeAvailable];
        
    }
}

-(void)processItemListAvailableNotification:(NSNotification*)notification{
    
    NSDictionary* userInfo =notification.userInfo;
    
    if(_waitingForData){
        
        DDLogVerbose(@"The user interface was waiting for data, processing the received items");
        
        NSInteger libraryID = [[userInfo objectForKey:ZPKEY_LIBRARY_ID] integerValue];
        NSString* collectionKey = [userInfo objectForKey:ZPKEY_COLLECTION_KEY];
        NSString* searchString = [userInfo objectForKey:ZPKEY_SEARCH_STRING];
        NSString* orderField = [userInfo objectForKey:ZPKEY_SORT_COLUMN];
        NSArray* tags = [userInfo objectForKey:ZPKEY_TAG];
        BOOL sortDescending = [[userInfo objectForKey:ZPKEY_ORDER_DIRECTION] boolValue];
        
        //Check if this item list is the one that we are waiting for
        
        if(tags!= NULL && ! [tags isKindOfClass:[NSArray class]]){
            [NSException raise:@"Internal consistency exception" format:@"Internal consistency exception"];
        }
        
        if([ZPItemList instance].libraryID == libraryID &&
           (([ZPItemList instance].collectionKey == NULL && collectionKey == NULL) || [collectionKey isEqualToString:[ZPItemList instance].collectionKey]) &&
           (([ZPItemList instance].searchString == NULL && searchString == NULL) || [searchString isEqualToString:[ZPItemList instance].searchString]) &&
           [orderField isEqualToString:[ZPItemList instance].orderField] &&
           ((tags == NULL && [[ZPItemList instance].tags count] == 0) || [[ZPItemList instance].tags isEqualToArray:tags])  &&
           sortDescending == [ZPItemList instance].sortDescending){
            
            NSArray* itemKeys = notification.object;
            [[ZPItemList instance] configureServerKeys:itemKeys];
            [self makeAvailable];
        }
    }
    else{
        DDLogVerbose(@"The user interface was not waiting for data, ignored the received items");
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
        NSString* currentItemKey = [[(ZPItemListDataSource*)_tableView.dataSource contentArray] objectAtIndex: indexPath.row];
        [itemDetailViewController setSelectedItem:(ZPZoteroItem*)[ZPZoteroItem itemWithKey:currentItemKey]];
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
    
    [super viewDidLoad];
    _dataSource = [[ZPItemListDataSource alloc] init];
    _tableView.dataSource = _dataSource;
    
    // Do any additional setup after loading the view, typically from a nib.
    
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
    
    [self _configureSortArrow];
    [self configureView];
}

-(void)viewWillUnload{
    [super viewWillUnload];
}
- (void)viewDidUnload
{
    [super viewDidUnload];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //Set the data source to serve this view
    [ZPItemList instance].targetTableView = self.tableView;
}

- (void)viewDidAppear:(BOOL)animated
{
    
    //TODO: test that this does not add the object multiple times.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyLibraryWithCollectionsAvailable:) name:ZPNOTIFICATION_LIBRARY_WITH_COLLECTIONS_AVAILABLE object:nil];
    
    [ZPItemList instance].owner = self;
    [_tableView setContentOffset:_offset animated:NO];
    //Is the current item visible? If not, scroll to it
    
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
    //Store scroll position
    _offset = _tableView.contentOffset;
    
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
            [ZPItemList instance].sortDescending  = ! [ZPItemList instance].sortDescending;
        }
        else{
            _tagForActiveSortButton = tag;
            [ZPItemList instance].orderField = orderField;
            [ZPItemList instance].sortDescending = FALSE;
        }
        
        [self _configureSortArrow];
        [self configureView];
    }
    
}


-(void) _configureSortArrow{
    
    UIButton* selectedButton = NULL;
    
    for(UIBarButtonItem* view in _toolBar.items){
        if(view.tag == _tagForActiveSortButton){
            selectedButton = (UIButton*) view.customView;
            break;
        }
    }
    
    if(_sortDirectionArrow==NULL){
        _sortDirectionArrow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"icon-up-black.png"]];
        _sortDirectionArrow.alpha = 0.25f;
    }
    else if(_sortDirectionArrow.superview != selectedButton){
        [_sortDirectionArrow removeFromSuperview];
    }
    
    
    if(selectedButton != NULL && _sortDirectionArrow.superview == NULL){
        [selectedButton insertSubview:_sortDirectionArrow atIndex:1];
        CGRect bounds = selectedButton.bounds;
        _sortDirectionArrow.center = CGPointMake(bounds.size.width / 2, bounds.size.height / 2);
        
    }
    //OPTIMIZATION: consider storing the images
    _sortDirectionArrow.image = [UIImage imageNamed:([ZPItemList instance].sortDescending ? @"icon-down-black.png":@"icon-up-black.png")];
    
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
    [ZPItemList instance].searchString = NULL;
    [_searchBar setText:@""];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sourceSearchBar{
    
    [self doneSearchingClicked:NULL];
    
    if(![[sourceSearchBar text] isEqualToString:[ZPItemList instance].searchString]){
        [ZPItemList instance].searchString = [sourceSearchBar text];
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

#pragma mark Notified methods

-(void) notifyLibraryWithCollectionsAvailable:(NSNotification*) notification{
    
    //If we are not showing any library, choose the first library
    
    if([ZPItemList instance].libraryID == LIBRARY_ID_NOT_SET ){
        if([NSThread isMainThread]){
            [self configureView];
        }
        else{
            [self performSelectorOnMainThread:@selector( notifyLibraryWithCollectionsAvailable:) withObject:notification waitUntilDone:YES];
        }
    }
}

// Update the item list when attachments become available

-(void) notifyAttachmentAvailable:(NSNotification*) notification{
    NSArray* attachments = notification.object;
    
    NSMutableArray* reloadIndices = [[NSMutableArray alloc] init];
    
    //Reload the cells containing the parent items if they do not have attachments showing.
    
    for(ZPZoteroAttachment* attachment in attachments){
        
        //Skip standalone attachments
        
        if(![attachment.key isEqual:attachment.parentKey ]){
            
            //Only process items that are in the active library
            
            if(attachment.libraryID == [ZPItemList instance].libraryID){
                ZPZoteroItem* parent = [ZPZoteroItem itemWithKey:attachment.parentKey];
                
                //Is the parent shown in the tableview?
                
                NSUInteger index = [_dataSource.contentArray indexOfObject:parent.itemKey];
                
                if(index != NSNotFound){
                    
                    // Is the parent visible?
                    
                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                    if ([self.tableView.indexPathsForVisibleRows containsObject:indexPath]) {
                        
                        //Is this the first attachment for the parent?
                        
                        if([[parent.attachments objectAtIndex:0] isEqual:attachment]){
                            
                            // Does the cell currently have a visible thumbnail ?
                            
                            UITableViewCell* cell = [self.tableView cellForRowAtIndexPath: indexPath];
                            
                            if(cell != NULL && [cell viewWithTag:4].hidden){
                                //If not, reload the cell
                                [reloadIndices addObject:indexPath];
                            }
                        }
                    }
                }
            }
        }
    }
    
    if([reloadIndices count]>0){
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            @synchronized(self.tableView){
                [self.tableView reloadRowsAtIndexPaths:reloadIndices withRowAnimation:UITableViewRowAnimationNone];
            }
        });
    }
}

//TODO: Refactor these away by making the thumbnail listen to notifications

-(void) notifyAttachmentDownloadFinished:(NSNotification*) notification{
    
    ZPZoteroAttachment* attachment = notification.object;
    
    //Skip standalone attachments
    
    if(![attachment.key isEqual:attachment.parentKey ]){
        
        //Only process items that are in the active library
        
        if(attachment.libraryID == [ZPItemList instance].libraryID){
            ZPZoteroItem* parent = [ZPZoteroItem itemWithKey:attachment.parentKey];
            
            //Is the parent shown in the tableview?
            
            NSUInteger index = [_dataSource.contentArray indexOfObject:parent.itemKey];
            
            if(index != NSNotFound){
                
                // Is the parent visible?
                
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                if ([self.tableView.indexPathsForVisibleRows containsObject:indexPath]) {
                    
                    //Is this the first attachment for the parent?
                    
                    if([[parent.attachments objectAtIndex:0] isEqual:attachment]){
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            @synchronized(self.tableView){
                                [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
                            }
                        });
                    }
                }
            }
        }
    }
}

-(void) notifyAttachmentDeleted:(NSNotification*) notification{
    ZPZoteroAttachment* attachment = notification.object;
    
    //Skip standalone attachments
    
    if(![attachment.key isEqual:attachment.parentKey ]){
        
        //Only process items that are in the active library
        
        if(attachment.libraryID == [ZPItemList instance].libraryID){
            ZPZoteroItem* parent = [ZPZoteroItem itemWithKey:attachment.parentKey];
            
            //Is the parent shown in the tableview?
            
            NSUInteger index = [_dataSource.contentArray indexOfObject:parent.itemKey];
            
            if(index != NSNotFound){
                
                // Is the parent visible?
                
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                if ([self.tableView.indexPathsForVisibleRows containsObject:indexPath]) {
                    
                    //Is this the first attachment for the parent?
                    
                    if([[parent.attachments objectAtIndex:0] isEqual:attachment]){
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            @synchronized(self.tableView){
                                [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
                            }
                        });
                    }
                }
            }
        }
    }
    
}

@end
