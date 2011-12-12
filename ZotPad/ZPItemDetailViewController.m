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
#import "ZPSimpleItemListViewController.h"
#import "ZPDetailedItemListViewController.h"
#import "ZPDataLayer.h"


#define TITLE_VIEW_HEIGHT 100
#define ATTACHMENT_VIEW_HEIGHT 500

@interface ZPItemDetailViewController();

- (void)_reconfigureDetailTableView;

@end

@implementation ZPItemDetailViewController

@synthesize selectedItem = _currentItem;
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
    
    [[ZPDataLayer instance] registerItemObserver:self];
    
    //Configure the size of the title section
    //The positions and sizes are set programmatically because this is difficult to get right with Interface Builder
    
    //The view must overflow 1 pixel on both sides to hide side borders

    UILabel *titleLabel = (UILabel *)[self.view viewWithTag:1];
    
    _fullCitationLabel= [[TTStyledTextLabel alloc] 
                                           initWithFrame:CGRectMake(-1,0, 
                                                                    self.view.frame.size.width+2, 
                                                                    TITLE_VIEW_HEIGHT)];
    
    [_fullCitationLabel setFont:[titleLabel font]];
    [_fullCitationLabel setClipsToBounds:TRUE];
    
    //Top, bottom, left, right
    [_fullCitationLabel setContentInset:UIEdgeInsetsMake(5,5,10,10)];
    
    _fullCitationLabel.layer.borderColor = [_detailTableView separatorColor].CGColor;
    _fullCitationLabel.layer.borderWidth = 1.0f;
    
    //Clear the old content and add the title label
    [[titleLabel superview] addSubview: _fullCitationLabel];
    [titleLabel removeFromSuperview];
    
    
    //Configure attachment section. Attachment section will be always shown even if there are no attachments
    
    UIView* attachmentView = [self.view viewWithTag:2];
    [attachmentView setFrame:CGRectMake(-1,TITLE_VIEW_HEIGHT-1, 
                                                   self.view.frame.size.width+2, 
                                                   ATTACHMENT_VIEW_HEIGHT+1)];

    attachmentView.layer.borderColor = [_detailTableView separatorColor].CGColor;
    attachmentView.layer.borderWidth = 1.0f;
    

    // Get the selected row from the item list
    NSIndexPath* indexPath = [[[ZPDetailedItemListViewController instance] tableView] indexPathForSelectedRow];
    
    // Get the key for the selected item 
    NSString* currentItemKey = [[[ZPDetailedItemListViewController instance] itemKeysShown] objectAtIndex: indexPath.row]; 
    
    [self configureWithItemKey: currentItemKey];

    
    
    //Show the item view in the navigator
    _itemListController = [self.storyboard instantiateViewControllerWithIdentifier:@"NavigationItemListView"];
    
    [_itemListController setItemKeysShown:[[ZPDetailedItemListViewController instance] itemKeysShown]];
    
    _itemListController.navigationItem.hidesBackButton = YES;
    
    
    [[[ZPLibraryAndCollectionListViewController instance] navigationController] pushViewController:_itemListController  animated:YES];

	[super viewWillAppear:animated];
    
    //Set the selected row to match the current row
    [[_itemListController tableView] selectRowAtIndexPath:indexPath animated:FALSE scrollPosition:UITableViewScrollPositionMiddle];

    _detailTableView.scrollEnabled = FALSE;
    
    [_itemListController.tableView setDelegate: self];

}

-(void) configureWithItemKey:(NSString*)key{
    
    _currentItem = [[ZPDataLayer instance] getItemByKey: key];
    
    // If there is no detailed information available for this item, tell teh data layer to retrieve it
    if(_currentItem.fields == NULL || _currentItem.attachments == NULL || _currentItem.creators == NULL){
        [[ZPDataLayer instance] updateItemDetailsFromServer:_currentItem];
    }
    
    TTStyledText* text = [TTStyledText textFromXHTML:[_currentItem.fullCitation stringByReplacingOccurrencesOfString:@" & " 
                                                                                                           withString:@" &amp; "] lineBreaks:YES URLs:NO];
    [_fullCitationLabel setText:text];
    
    
    [self _reconfigureDetailTableView ];
    
}

- (void)_reconfigureDetailTableView {
    
    //Configure the size of the detail view table.

    [_detailTableView reloadData];
    
    [_detailTableView layoutIfNeeded];
    
    [_detailTableView setFrame:CGRectMake(0, 
                                          TITLE_VIEW_HEIGHT + ATTACHMENT_VIEW_HEIGHT, 
                                          self.view.frame.size.width, 
                                          [_detailTableView contentSize].height)];
    
    //Configure  the size of the UIScrollView
    [(UIScrollView*) self.view setContentSize:CGSizeMake(self.view.frame.size.width, TITLE_VIEW_HEIGHT + ATTACHMENT_VIEW_HEIGHT + [_detailTableView contentSize].height)];
    
}
- (void)viewWillDisappear:(BOOL)animated
{
    //Pop the item navigator away from the navigator.
    
    [[[ZPLibraryAndCollectionListViewController instance] navigationController] popViewControllerAnimated:YES];
    
    [[ZPDataLayer instance] removeItemObserver:self];
    
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
    //Item type and title
    if(section==0){
        return 2;
    }
    //Creators
    if(section==1){
        if(_currentItem.creators!=NULL){
            return [_currentItem.creators count];
        }
        else{
            return 0;
        }
    }
    //Rest of the fields
    if(section==2){
        if(_currentItem.fields!=NULL){
            //Two fields, itemType and title, are shown separately
            return [_currentItem.fields count]-2;
        }
        else{
            return 0;
        }

    }

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

    //TODO: resolve localization and  field order using the Zotero server
    
    //Title and itemtype
    if([indexPath indexAtPosition:0] == 0){
        if(indexPath.row == 0){
            cell.textLabel.text = @"Title";
            cell.detailTextLabel.text = _currentItem.title;
        }
        if(indexPath.row == 1){
            cell.textLabel.text = @"Item type";
            cell.detailTextLabel.text = _currentItem.itemType;
        }

    }
    //Creators
    else if([indexPath indexAtPosition:0] == 1){
        NSDictionary* creator=[_currentItem.creators objectAtIndex:indexPath.row];
        cell.textLabel.text = [creator objectForKey:@"creatorType"];
        
        NSString* lastName = [creator objectForKey:@"lastName"];
        if(lastName==NULL || [lastName isEqualToString:@""]){
            cell.detailTextLabel.text = [creator objectForKey:@"shortName"];
        }
        else{
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@",[creator objectForKey:@"firstName"],lastName];
        }
    }
    
    //Reset of the fields
    else{
        NSEnumerator* e = [_currentItem.fields keyEnumerator]; 
        
        NSInteger index = -1;
        NSString* key;
        while(key = [e nextObject]){
            if(! [key isEqualToString:@"itemType"] && ! [key isEqualToString:@"title"]){
                index++;
            }
            
            if(index==indexPath.row){
                break;
            }
        }
        cell.textLabel.text = key;
        cell.detailTextLabel.text = [_currentItem.fields objectForKey:key];
    }
    
	return ( cell );
}

/*
    
 This takes care of both the details table and table that constains the list of items in the navigator
 
 */

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Item details
    
    if(aTableView == _detailTableView){
        
    }
    
    // Navigator list view
    
    else{
        
        // Get the key for the selected item 
        NSString* currentItemKey = [[_itemListController itemKeysShown] objectAtIndex: indexPath.row]; 
        
        [self configureWithItemKey: currentItemKey];
        
    }
}

#pragma mark-
#pragma mark Observer methods

/*
    These are called by data layer to notify that more information about an item has become available from the server
 */

-(void) notifyItemDetailsAvailable:(ZPZoteroItem*) item{
    
    //TODO: Modifying the DetailViewTable could be animated.
    
    if([item.key isEqualToString:_currentItem.key]){
        _currentItem = item;
        [self performSelectorOnMainThread:@selector( _reconfigureDetailTableView) withObject:nil waitUntilDone:NO];
    }
}

-(void) notifyItemAttachmentInformationAvailable:(ZPZoteroItem*) item{
    
}

-(void) notifyItemAttachmentFileAvailable:(ZPZoteroItem*) item{
    
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
	UIView* view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
	UILabel* label = [[UILabel alloc] initWithFrame:view.bounds];
	label.text = [NSString stringWithFormat:@"Item %i",index];
	label.backgroundColor = [UIColor clearColor];
	label.textAlignment = UITextAlignmentCenter;
	label.font = [label.font fontWithSize:50];
	[view addSubview:label];
	return view;
}


@end
