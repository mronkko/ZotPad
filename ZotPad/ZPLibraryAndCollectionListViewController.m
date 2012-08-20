//
//  ZPLibraryAndCollectionViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"
#import "ZPLibraryAndCollectionListViewController.h"
#import "ZPItemListViewController.h"
#import "ZPDataLayer.h"
#import "ZPServerConnection.h"
#import "ZPAuthenticationDialog.h"
#import "ZPAppDelegate.h"
#import "ZPCacheController.h"
#import "ZPCacheStatusToolbarController.h"
#import "ZPItemListViewDataSource.h"
#import "ZPHelpPopover.h"
#import "ZPMasterItemListViewController.h"

@implementation ZPLibraryAndCollectionListViewController

@synthesize detailViewController = _detailViewController;
@synthesize currentlibraryID = _currentlibraryID;
@synthesize currentCollectionKey = _currentCollectionKey;
@synthesize gearButton, cacheControllerPlaceHolder;

- (void)awakeFromNib
{
    self.clearsSelectionOnViewWillAppear = NO;
    self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
    [super awakeFromNib];
}

- (void)didReceiveMemoryWarning
{
    
    //Remove the cache status bar from the toolbar 
    
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
    
    // Release the cache status controller. 
    // TODO: Also release this in the cache controller

}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    
    DDLogInfo(@"Loading library and collection list in navigator");

    [super viewDidLoad];

    //TODO: Fix this activity indicator. There should be a reliable way to know when the
    //view is receiving new data and when it has received all data. This is complicated
    //by the fact that each item in the navigation stack is a separate view.
    //_activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0,0,20, 20)];
    //[_activityIndicator hidesWhenStopped];

    //UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
    //self.navigationItem.rightBarButtonItem = barButton;

    self.clearsSelectionOnViewWillAppear = NO;
    
	// Do any additional setup after loading the view, typically from a nib.
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        
        //Show Cache controller status, only on iPad
        ZPCacheStatusToolbarController* statusController = [[ZPCacheStatusToolbarController alloc] init];
        cacheControllerPlaceHolder.customView = statusController.view;

        UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;
        gearButton.target = root;
        gearButton.action = @selector(showLogView:);
    }
 

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
    
    //If the current library is not defined, show a list of libraries
    if(self->_currentlibraryID == LIBRARY_ID_NOT_SET){
        [[ZPCacheController instance] performSelectorInBackground:@selector(updateLibrariesAndCollectionsFromServer) withObject:NULL];
        self->_content = [[ZPDataLayer instance] libraries];
    }
    //If a library is chosen, show collections level collections for that library
    else{
        [[ZPCacheController instance] performSelectorInBackground:@selector(updateCollectionsForLibraryFromServer:) withObject:[ZPZoteroLibrary libraryWithID:_currentlibraryID]];
        self->_content = [[ZPDataLayer instance] collectionsForLibrary:self->_currentlibraryID withParentCollection:self->_currentCollectionKey];        
    }
    
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
    [[ZPDataLayer instance] registerLibraryObserver:self];
    self.detailViewController = (ZPItemListViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    [super viewDidAppear:animated];
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[ZPDataLayer instance] removeLibraryObserver:self];
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

// On iPhone the item list is shown with a segue

-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if([segue.identifier isEqualToString:@"PushItemList"]){
        ZPItemListViewController* target = (ZPItemListViewController*) segue.destinationViewController;
        ZPZoteroDataObject* node = [self->_content objectAtIndex: self.tableView.indexPathForSelectedRow.row];
        
        [ZPItemListViewDataSource instance].libraryID = [node libraryID];
        [ZPItemListViewDataSource instance].collectionKey = [node key];
        
        //Clear search when changing collection. This is how Zotero behaves
        [target clearSearch];
        [target configureView];
        
    }
    if([segue.identifier isEqualToString:@"PushItemsToNavigator"]){
        
        
        ZPMasterItemListViewController* target = (ZPMasterItemListViewController*) segue.destinationViewController;
        target.detailViewController = sender;
        target.tableView.delegate = sender;
        
        target.navigationItem.hidesBackButton = YES;
        target.clearsSelectionOnViewWillAppear = NO;
        
        //Keep the same toolbar
        [target setToolbarItems:self.toolbarItems];
         
         // Get the selected row from the item list
        ZPZoteroItem* selectedItem = [(ZPItemDetailViewController*)sender selectedItem];
        NSInteger index = [[[ZPItemListViewDataSource instance] itemKeysShown] indexOfObject:selectedItem.key];
        NSIndexPath* indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        [target.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionMiddle]; 
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    
    // Return YES for supported orientations
    return YES;
}


#pragma mark - 
#pragma mark Table view data source and delegate methods

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    DDLogVerbose(@"Rows in library/collection table %i",[self->_content count]);
    return [self->_content count];
}



- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
     NSString *CellIdentifier = @"CollectionCell";
    
    
    // Dequeue or create a cell of the appropriate type.
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
	{
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell.
	ZPZoteroDataObject* node = [self->_content objectAtIndex: indexPath.row];
	if ( [node hasChildren])
	{
		cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	}
	else
	{
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
	
    cell.textLabel.text = [node title];
    
    if(cell == NULL || ! [cell isKindOfClass:[UITableViewCell class]]){
        [NSException raise:@"Invalid cell" format:@""];
    }

	return cell;
}


// On iPad the item list is always shown if library and collection list is visible

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    /*
     When a row is selected, set the detail view controller's library and collection and refresh
     */
    ZPZoteroDataObject* node = [self->_content objectAtIndex: indexPath.row];
    [ZPItemListViewDataSource instance].libraryID = [node libraryID];
    [ZPItemListViewDataSource instance].collectionKey = [node key];
    
    if (self.detailViewController != NULL) {

        //Clear search when changing collection. This is how Zotero behaves
        [self.detailViewController clearSearch];
        [self.detailViewController configureView];
    }    
}


- (void) tableView: (UITableView *) aTableView accessoryButtonTappedForRowWithIndexPath: (NSIndexPath *) indexPath
{
    /*
     Drill down to a library or collection
    */
    
    
    ZPLibraryAndCollectionListViewController* subController = [self.storyboard instantiateViewControllerWithIdentifier:@"LibraryAndCollectionList"];
	subController.detailViewController = self.detailViewController;
    ZPZoteroDataObject* selectedNode  = [self->_content objectAtIndex: indexPath.row];
	subController.currentlibraryID=[selectedNode libraryID];
	subController.currentCollectionKey=[selectedNode key];
	
	[self.navigationController pushViewController: subController animated: YES];
	
}





#pragma mark - 
#pragma mark Notified methods

-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library{
    
    //Show popover
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        if([[NSUserDefaults standardUserDefaults] objectForKey:@"hasPresentedMainHelpPopover"]==NULL){
            [ZPHelpPopover displayHelpPopoverFromToolbarButton:gearButton];
            [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:@"hasPresentedMainHelpPopover"];
        }
    }


    //If this is a library that we are not showing now, just return;
    
    if(self->_currentlibraryID != library.libraryID) return;
    
    if([NSThread isMainThread]){
        
        //Loop over the existing content to see if we need to refresh the content of the cells that are already showing
        
        ZPZoteroDataObject* shownObject;
        NSInteger index=-1;
        
        for(shownObject in _content){
            index++;

            UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
            //Check accessory button
            BOOL noAccessory = cell.accessoryType == UITableViewCellAccessoryNone;
            if(shownObject.hasChildren && noAccessory){
                cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
            }
            else if(!shownObject.hasChildren && ! noAccessory){
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            
            //Check title
            
            if(![cell.textLabel.text isEqualToString:shownObject.title]){
                cell.textLabel.text = shownObject.title;
            }
        }
        
        //Then check if we need to insert, delete, or move cells
        
        NSArray* newContent;
        
        if(_currentlibraryID == LIBRARY_ID_NOT_SET){
            newContent = [[ZPDataLayer instance] libraries];        
        }
        else if(_currentlibraryID == library.libraryID){
            newContent = [[ZPDataLayer instance] collectionsForLibrary:self->_currentlibraryID withParentCollection:self->_currentCollectionKey];        
        }

        NSMutableArray* deleteArray = [[NSMutableArray alloc] init ];
        NSMutableArray* insertArray = [[NSMutableArray alloc] init ];

        NSMutableArray* shownContent = [NSMutableArray arrayWithArray:_content];
        
        index=-1;
        ZPZoteroDataObject* newObject;
        
        //First check which need to be inserted
        for(newObject in newContent){
            index++;
            
            NSInteger oldIndexOfNewObject= [shownContent indexOfObject:newObject];
                
            if(oldIndexOfNewObject == NSNotFound){
                [insertArray addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                [shownContent insertObject:newObject atIndex:index];
            }
        }
        
        //Then check which need to be deleted

        index=-1;
        
        for(shownObject in [NSArray arrayWithArray:shownContent]){
            index++;
            NSInteger newIndexOfOldObject= [newContent indexOfObject:shownObject];

            if(newIndexOfOldObject == NSNotFound){
                //If the new object does not exist in th old array, insert it
                [deleteArray addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                [shownContent removeObjectAtIndex:index];
            }
        }
        
        ZPZoteroDataObject* dataObj;
        
        DDLogVerbose(@"Libraries / collections before update");
        for(dataObj in _content){
            DDLogVerbose(@"%@",dataObj.title); 
        }
        _content = shownContent;
        
        [self.tableView beginUpdates];
         
        if([insertArray count]>0){
            [self.tableView insertRowsAtIndexPaths:insertArray withRowAnimation:UITableViewRowAnimationAutomatic];
            DDLogVerbose(@"Inserting rows into indices");
            NSIndexPath* temp;
            for(temp in insertArray){
                DDLogVerbose(@"%i",temp.row); 
            }

        }
        if([deleteArray count]>0){
            [self.tableView deleteRowsAtIndexPaths:deleteArray withRowAnimation:UITableViewRowAnimationAutomatic];
            DDLogVerbose(@"Deleting rows from indices");
            NSIndexPath* temp;
            for(temp in insertArray){
                DDLogVerbose(@"%i",temp.row); 
            }
        }
        
        [self.tableView endUpdates];
        DDLogVerbose(@"Libraries / collections after update");
        for(dataObj in _content){
            DDLogVerbose(@"%@",dataObj.title); 
        }
        
    //TODO: Figure out a way to keep the activity view spinning until the last library is loaded.
    //[_activityIndicator stopAnimating];
        
    }
    else{
        [self performSelectorOnMainThread:@selector( notifyLibraryWithCollectionsAvailable:) withObject:library waitUntilDone:YES];
    }
    
}


@end
