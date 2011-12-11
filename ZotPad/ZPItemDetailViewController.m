//
//  ZPItemDetailViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/4/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//


//TODO: Change this to table view controller

#import "ZPItemDetailViewController.h"
#import "ZPLibraryAndCollectionListViewController.h"
#import "ZPNavigationItemListViewController.h"
#import "ZPItemListViewController.h"
#import "ZPDataLayer.h"


#define TITLE_VIEW_HEIGHT 100
#define ATTACHMENT_VIEW_HEIGHT 500

@implementation ZPItemDetailViewController

@synthesize selectedItem = _selectedItem;
@synthesize detailTableView = _detailTableView;
@synthesize carousel = _carousel;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //configure carousel
    _carousel.type = iCarouselTypeCoverFlow2;

    NSLog(@"Item detail view loaded");
}

- (void)viewWillAppear:(BOOL)animated
{
    // Get the selected row from the item list
    NSIndexPath* indexPath = [[[ZPItemListViewController instance] tableView] indexPathForSelectedRow];
    


    // Get the key for the selected item 
    NSString* currentItemKey = [[[ZPItemListViewController instance] itemKeysShown] objectAtIndex: indexPath.row]; 

    _selectedItem = [[ZPDataLayer instance] getItemByKey: currentItemKey];

    
    //Configure the size of the title section
    //The positions and sizes are set programmatically because this is difficult to get right with Interface Builder
    
    //The view must overflow 1 pixel on both sides to hide side borders

    UILabel *titleLabel = (UILabel *)[self.view viewWithTag:1];
    
    TTStyledTextLabel* fullCitationLabel= [[TTStyledTextLabel alloc] 
                                           initWithFrame:CGRectMake(-1,0, 
                                                                    self.view.frame.size.width+2, 
                                                                    TITLE_VIEW_HEIGHT)];
    
    [fullCitationLabel setFont:[titleLabel font]];
    [fullCitationLabel setClipsToBounds:TRUE];
    
    //Top, bottom, left, right
    [fullCitationLabel setContentInset:UIEdgeInsetsMake(5,5,10,10)];
    
    TTStyledText* text = [TTStyledText textFromXHTML:[_selectedItem.fullCitation stringByReplacingOccurrencesOfString:@" & " 
                                                                                                           withString:@" &amp; "] lineBreaks:YES URLs:NO];
    [fullCitationLabel setText:text];
    
    
    fullCitationLabel.layer.borderColor = [_detailTableView separatorColor].CGColor;
    fullCitationLabel.layer.borderWidth = 1.0f;
    
    //Clear the old content and add the title label
    [[titleLabel superview] addSubview: fullCitationLabel];
    [titleLabel removeFromSuperview];
    
    
    //Configure attachment section. Attachment section will be always shown even if there are no attachments
    
    UIView* attachmentView = [self.view viewWithTag:2];
    [attachmentView setFrame:CGRectMake(-1,TITLE_VIEW_HEIGHT-1, 
                                                   self.view.frame.size.width+2, 
                                                   ATTACHMENT_VIEW_HEIGHT+1)];

    attachmentView.layer.borderColor = [_detailTableView separatorColor].CGColor;
    attachmentView.layer.borderWidth = 1.0f;
    
    //Configure the size of the detail view table.
    
    [_detailTableView layoutIfNeeded];
    
    [_detailTableView setFrame:CGRectMake(0, 
                                          TITLE_VIEW_HEIGHT + ATTACHMENT_VIEW_HEIGHT, 
                                          self.view.frame.size.width, 
                                          [_detailTableView contentSize].height)];
    
    //Configure  the size of the UIScrollView
    [(UIScrollView*) self.view setContentSize:CGSizeMake(self.view.frame.size.width, TITLE_VIEW_HEIGHT + ATTACHMENT_VIEW_HEIGHT + [_detailTableView contentSize].height)];
    
    
    
    //Show the item view in the navigator
    UITableViewController* itemListController = [self.storyboard instantiateViewControllerWithIdentifier:@"NavigationItemListView"];
        
    [[[ZPLibraryAndCollectionListViewController instance] navigationController] pushViewController:itemListController  animated:YES];

	[super viewWillDisappear:animated];
    
    //Set the selected row to match the current row
    [[itemListController tableView] selectRowAtIndexPath:indexPath animated:FALSE scrollPosition:UITableViewScrollPositionMiddle];

    _detailTableView.scrollEnabled = FALSE;
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    //Pop the item navigator away from the navigator.
    
    [[[ZPLibraryAndCollectionListViewController instance] navigationController] popViewControllerAnimated:YES];
    
    
	[super viewWillDisappear:animated];
}

     
/*
 
 sections
 1) Type and title
 2) Creators
 3) Other details
 

*/

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}





 
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *CellIdentifier;
    
    //The first section
    CellIdentifier = @"ItemDetailCell";        

    // Dequeue or create a cell of the appropriate type.
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
	{
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell
    
    
	return ( cell );
}


#pragma mark -
#pragma mark iCarousel methods

- (NSUInteger)numberOfItemsInCarousel:(iCarousel *)carousel
{
    return 5;
}


- (UIView *)carousel:(iCarousel *)carousel viewForItemAtIndex:(NSUInteger)index
{
    //create a numbered view
	UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
	UILabel *label = [[UILabel alloc] initWithFrame:view.bounds];
	label.text = [NSString stringWithFormat:@"Item %i",index];
	label.backgroundColor = [UIColor clearColor];
	label.textAlignment = UITextAlignmentCenter;
	label.font = [label.font fontWithSize:50];
	[view addSubview:label];
	return view;
}


@end
