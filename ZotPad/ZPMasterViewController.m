//
//  ZPMasterViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPMasterViewController.h"
#import "ZPDetailViewController.h"
#import "ZPNavigatorNode.h"
#import "ZPDataLayer.h"

@implementation ZPMasterViewController

@synthesize detailViewController = _detailViewController;
@synthesize currentLibrary = _currentLibrary;
@synthesize currentCollection = _currentCollection;


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

    //Initialize database if it does not exists

    
    //If the current library is not defined, show a list of libraries
    if(self->_currentLibrary == 0){
        self->_content = [[ZPDataLayer instance] libraries];
    }
    //If a library is chosen, show collections level collections for that library
    else{
        self->_content = [[ZPDataLayer instance] collections:self->_currentLibrary currentCollection:self->_currentCollection];        
    }
    
	// Do any additional setup after loading the view, typically from a nib.
    self.detailViewController = (ZPDetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
    }
}


- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [self->_content count];
}




- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
     NSString *CellIdentifier = @"NavigationItemCellIdentifier";
    
    //TODO:
    // Read this http://stackoverflow.com/questions/7911588/should-xcode-storyboard-support-segues-from-a-uitableview-with-dynamic-prototy
    // Fix iPhone seque from navigator cell to detail view
    
    // Dequeue or create a cell of the appropriate type.
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
	{
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell.
	ZPNavigatorNode* node = [self->_content objectAtIndex: indexPath.row];
	if ( [node hasChildren])
	{
		cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	}
	else
	{
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
	
    cell.textLabel.text = [node name];
    
	return ( cell );
}


- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    /*
     When a row is selected, set the detail view controller's library and collection and refresh
     */
    
    ZPNavigatorNode* node = [self->_content objectAtIndex: indexPath.row];
    self.detailViewController.libraryID = [node libraryID];
    self.detailViewController.collectionID = [node collectionID];
    
    [self.detailViewController configureView];
    
}

- (void) tableView: (UITableView *) aTableView accessoryButtonTappedForRowWithIndexPath: (NSIndexPath *) indexPath
{
    /*
     Drill down to a library or collection
    */
    
    ZPMasterViewController* subController = [[ZPMasterViewController alloc] initWithStyle: UITableViewStylePlain];
	subController.detailViewController = self.detailViewController;
    ZPNavigatorNode* selectedNode = [self->_content objectAtIndex: indexPath.row];
	subController.currentLibrary=[selectedNode libraryID];
	subController.currentCollection=[selectedNode collectionID];
	
	[self.navigationController pushViewController: subController animated: YES];
	
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

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source.
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

@end
