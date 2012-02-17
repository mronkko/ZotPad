//
//  ZPLibraryAndCollectionViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPLibraryAndCollectionListViewController.h"
#import "ZPItemListViewController.h"
#import "ZPDataLayer.h"
#import "ZPServerConnection.h"
#import "ZPAuthenticationDialog.h"
#import "ZPAppDelegate.h"
#import "ZPZoteroLibrary.h"
#import "ZPCacheController.h"
#import "ZPLogger.h"
#import "ZPPreferences.h"


@interface ZPLibraryAndCollectionListViewController();
//-(void) _refreshLibrariesAndCollections;
@end


@implementation ZPLibraryAndCollectionListViewController

@synthesize detailViewController = _detailViewController;
@synthesize currentlibraryID = _currentlibraryID;
@synthesize currentCollectionKey = _currentCollectionKey;

static ZPLibraryAndCollectionListViewController* _instance = nil;

+ (ZPLibraryAndCollectionListViewController*) instance{
    return _instance;
}

- (void)awakeFromNib
{
    self.clearsSelectionOnViewWillAppear = NO;
    self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
    [super awakeFromNib];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    //TODO: Fix this activity indicator. There should be a reliable way to know when the
    //view is receiving new data and when it has received all data. This is complicated
    //by the fact that each item in the navigation stack is a separate view.
    //_activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0,0,20, 20)];
    //[_activityIndicator hidesWhenStopped];

    //UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
    //self.navigationItem.rightBarButtonItem = barButton;

    //[self performSelectorInBackground:@selector(_refreshLibrariesAndCollections) withObject:NULL];

    //If the current library is not defined, show a list of libraries
    if(self->_currentlibraryID == 0){
        self->_content = [[ZPDataLayer instance] libraries];
    }
    //If a library is chosen, show collections level collections for that library
    else{
        self->_content = [[ZPDataLayer instance] collectionsForLibrary:self->_currentlibraryID withParentCollection:self->_currentCollectionKey];        
    }
    
	// Do any additional setup after loading the view, typically from a nib.
    self.detailViewController = (ZPItemListViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
 
}


- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [self->_content count];
}

/*
// TODO: Not currently used. Figure out logic for retriecing new data from the server for collections. 

-(void) _refreshLibrariesAndCollections {
    if([[ZPPreferences instance] online]){
        [_activityIndicator startAnimating];
        [[ZPCacheController instance] updateLibrariesAndCollectionsFromServer];
    }
}
*/
//TODO: Instead of realoding everything, this method should just add or update the library that it receives

-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library{


    if([NSThread isMainThread]){
        
        NSIndexPath* selected = [[self tableView] indexPathForSelectedRow];
        //If we are showing the libraries view, reload the data

        //If the current library is not defined, show a list of libraries
        if(self->_currentlibraryID == 0){
            [ZPZoteroLibrary dropCache]; //TODO: Figure a more elegant solution
            self->_content = [[ZPDataLayer instance] libraries];
        }
        //If a library is chosen, show collections level collections for that library
        else{
            [ZPZoteroCollection dropCache]; //TODO: Figure a more elegant solution
            self->_content = [[ZPDataLayer instance] collectionsForLibrary:self->_currentlibraryID withParentCollection:self->_currentCollectionKey];        
        }
        
        [[self tableView] reloadData];
        if(selected!=NULL) [[self tableView] selectRowAtIndexPath:selected animated:FALSE scrollPosition:UITableViewScrollPositionNone];

        //TODO: Figure out a way to keep the activity view spinning until the last library is loaded.
        //[_activityIndicator stopAnimating];

    }
    else{
        [self performSelectorOnMainThread:@selector( notifyLibraryWithCollectionsAvailable:) withObject:library waitUntilDone:NO];
    }
    
}



- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
     NSString *CellIdentifier = @"CollectionCell";
    
    // TODO:
    // Read this http://stackoverflow.com/questions/7911588/should-xcode-storyboard-support-segues-from-a-uitableview-with-dynamic-prototy
    // Fix iPhone seque from navigator cell to detail view
    
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
    
	return ( cell );
}


- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    /*
     When a row is selected, set the detail view controller's library and collection and refresh
     */
    
   ZPZoteroDataObject* node = [self->_content objectAtIndex: indexPath.row];
    self.detailViewController.libraryID = [node libraryID];
    self.detailViewController.collectionKey = [node key];

    //Clear search when changing collection. This is how Zotero behaves
    [self.detailViewController clearSearch];
     
    [self.detailViewController configureView];
    
}

- (void) tableView: (UITableView *) aTableView accessoryButtonTappedForRowWithIndexPath: (NSIndexPath *) indexPath
{
    /*
     Drill down to a library or collection
    */
    
    ZPLibraryAndCollectionListViewController* subController = [[ZPLibraryAndCollectionListViewController alloc] initWithStyle: UITableViewStylePlain];
	subController.detailViewController = self.detailViewController;
    ZPZoteroDataObject* selectedNode  = [self->_content objectAtIndex: indexPath.row];
	subController.currentlibraryID=[selectedNode libraryID];
	subController.currentCollectionKey=[selectedNode key];
	
	[self.navigationController pushViewController: subController animated: YES];
	
}
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    // Make sure your segue name in storyboard is the same as this line
    if ([[segue identifier] isEqualToString:@"PushItemsToNavigator"])
    {
        
        UITableViewController* simpleItemListViewController = (UITableViewController*)[segue destinationViewController];

        simpleItemListViewController.navigationItem.hidesBackButton = YES;

        ZPItemListViewController* itemList = (ZPItemListViewController*) sender;

        // Get the selected row from the item list
        NSIndexPath* indexPath = [[itemList tableView] indexPathForSelectedRow];
        simpleItemListViewController.tableView.dataSource = sender;
        simpleItemListViewController.tableView.delegate = 
        //TODO: set the selected row
        //[simpleItemListViewController.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionMiddle]; 
        
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
}

- (void)viewDidAppear:(BOOL)animated
{
    [[ZPDataLayer instance] registerLibraryObserver:self];
    _instance= self;
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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    
    // Return YES for supported orientations
    return YES;
}


@end
