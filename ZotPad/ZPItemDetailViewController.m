//
//  ZPItemDetailViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/4/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPItemDetailViewController.h"
#import "ZPLibraryAndCollectionListViewController.h"
#import "ZPSimpleItemListViewController.h"
#import "ZPDetailedItemListViewController.h"
#import "ZPDataLayer.h"
#import "ZPLocalization.h"
#import "ZPFileThumbnailAndQuicklookController.h"
#import "ZPLogger.h"

#define ATTACHMENT_VIEW_HEIGHT 680

#define ATTACHMENT_IMAGE_HEIGHT 600
#define ATTACHMENT_IMAGE_WIDTH 423

@interface ZPItemDetailViewController();
- (void) _reconfigureDetailTableView;
- (void) _reconfigureAttachmentsCarousel;
@end

@implementation ZPItemDetailViewController


@synthesize selectedItem = _currentItem;
@synthesize detailTableView = _detailTableView;
@synthesize carousel = _carousel;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[ZPDataLayer instance] registerItemObserver:self];
    [[ZPDataLayer instance] registerAttachmentObserver:self];

    _detailTableView.scrollEnabled = FALSE;
    

  
    //configure carousel
    _carousel.type = iCarouselTypeCoverFlow2;
    _carouselViews = [[NSMutableArray alloc] init];
    
    //Show the item view in the navigator
    _itemListController = [self.storyboard instantiateViewControllerWithIdentifier:@"NavigationItemListView"];
    _itemListController.navigationItem.hidesBackButton = YES;
    
    
    //Configure attachment section. Attachment section will be always shown even if there are no attachments
    
    UIView* attachmentView = [self.view viewWithTag:2];
    [attachmentView setFrame:CGRectMake(0,0, 
                                        self.view.frame.size.width,
                                        ATTACHMENT_VIEW_HEIGHT)];
    
    //Configure activity indicator.
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0,0,20, 20)];
    [_activityIndicator hidesWhenStopped];
    UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
    self.navigationItem.rightBarButtonItem = barButton;



}

- (void)viewWillAppear:(BOOL)animated
{
    

    [super viewWillAppear:animated];


    // Get the selected row from the item list
    NSIndexPath* indexPath = [[[ZPDetailedItemListViewController instance] tableView] indexPathForSelectedRow];
    
    // Get the key for the selected item 
    NSString* currentItemKey = [[[ZPDetailedItemListViewController instance] itemKeysShown] objectAtIndex: indexPath.row]; 
    
    // Set the navigation controller
    [_itemListController configureWithItemListController:[ZPDetailedItemListViewController instance]];
    
    [[[ZPLibraryAndCollectionListViewController instance] navigationController] pushViewController:_itemListController  animated:YES];
    
    [_itemListController.tableView setDelegate: self];

    [self configureWithItemKey: currentItemKey];

}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    

}


- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration{
    UIView* attachmentView = [self.view viewWithTag:2];
    [attachmentView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [_detailTableView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}


-(void) configureWithItemKey:(NSString*)key{
    
    _currentItem = [ZPZoteroItem retrieveOrInitializeWithKey: key];
    [_activityIndicator startAnimating];
    [[ZPDataLayer instance] updateItemDetailsFromServer:_currentItem];

    // Get the selected row from the item list
    NSUInteger indexArr[] = {0,[_itemListController.itemKeysShown indexOfObject:key]};
    NSIndexPath* indexPath = [NSIndexPath indexPathWithIndexes:indexArr length:2];
    
    //Set the selected row to match the current row
    [[_itemListController tableView] selectRowAtIndexPath:indexPath animated:FALSE scrollPosition:UITableViewScrollPositionMiddle];

        
    [self _reconfigureDetailTableView];
    [self _reconfigureAttachmentsCarousel];
    
    if(_currentItem.creatorSummary!=NULL && ! [_currentItem.creatorSummary isEqualToString:@""]){
        if(_currentItem.year!=0){
            self.navigationItem.title=[NSString stringWithFormat:@"%@ (%i) %@",_currentItem.creatorSummary,_currentItem.year,_currentItem.title];
        }
        else{
            self.navigationItem.title=[NSString stringWithFormat:@"%@ (no date) %@",_currentItem.creatorSummary,_currentItem.title];;
        }
    }
    else{
        self.navigationItem.title=_currentItem.title;
    }
    
    _previewController = [[ZPFileThumbnailAndQuicklookController alloc] initWithItem:_currentItem viewController:self maxHeight:ATTACHMENT_IMAGE_HEIGHT maxWidth:ATTACHMENT_IMAGE_WIDTH];

}

-(void) _reconfigureAttachmentsCarousel{
    
    [_carouselViews removeAllObjects];
    
    ZPZoteroAttachment* attachment;
    for (attachment in _currentItem.attachments) {
        UIView* view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ATTACHMENT_IMAGE_WIDTH, ATTACHMENT_IMAGE_HEIGHT)];
        [_carouselViews addObject:view];
        [_previewController configurePreview:view withAttachment:attachment];
    }
    
    [_carousel reloadData];
    
}
- (void)_reconfigureDetailTableView{
    
    //Configure the size of the detail view table.
    
    [_detailTableView reloadData];
    
    [_detailTableView layoutIfNeeded];
    
    [_detailTableView setFrame:CGRectMake(0, 
                                          ATTACHMENT_VIEW_HEIGHT, 
                                          self.view.frame.size.width, 
                                          [_detailTableView contentSize].height)];

    
    //Configure  the size of the UIScrollView
    [(UIScrollView*) self.view setContentSize:CGSizeMake(self.view.frame.size.width, ATTACHMENT_VIEW_HEIGHT + [_detailTableView contentSize].height)];
    
    
    
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
        if(_currentItem.creators!=NULL || [_currentItem.itemType isEqualToString:@"attachment"]|| [_currentItem.itemType isEqualToString:@"note"]){
            return [_currentItem.creators count];
        }
        else{
            return 0;
        }
    }
    //Rest of the fields
    if(section==2){
        if(_currentItem.fields!=NULL || [_currentItem.itemType isEqualToString:@"attachment"]|| [_currentItem.itemType isEqualToString:@"note"]){
            //Two fields, itemType and title, are shown separately
            return [_currentItem.fields count]-2;
        }
        else{
            return 0;
        }

    }
    //This should not happen
    return 0;
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

    
    //Title and itemtype
    if([indexPath indexAtPosition:0] == 0){
        if(indexPath.row == 0){
            cell.textLabel.text = @"Title";
            cell.detailTextLabel.text = _currentItem.title;
        }
        if(indexPath.row == 1){
            cell.textLabel.text = @"Item type";
            cell.detailTextLabel.text = [ZPLocalization getLocalizationStringWithKey:_currentItem.itemType  type:@"itemType" locale:NULL];
        }

    }
    //Creators
    else if([indexPath indexAtPosition:0] == 1){
        NSDictionary* creator=[_currentItem.creators objectAtIndex:indexPath.row];
        cell.textLabel.text = [ZPLocalization getLocalizationStringWithKey:[creator objectForKey:@"creatorType"] type:@"creatorType" locale:NULL];
        
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
        
        cell.textLabel.text = [ZPLocalization getLocalizationStringWithKey:key  type:@"field" locale:NULL];
        cell.detailTextLabel.text = [_currentItem.fields objectForKey:key];
    }
    
	return ( cell );
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Item details
    
    if(aTableView == _detailTableView){
        
    }
    
    // Navigator list view
    
    else{
        
        // Get the key for the selected item 
        NSString* currentItemKey = [[_itemListController itemKeysShown] objectAtIndex: indexPath.row]; 
        
        if(currentItemKey != [NSNull null]) [self configureWithItemKey: currentItemKey];
        
    }
}


#pragma mark-


/*
    
 This takes care of both the details table and table that constains the list of items in the navigator
 
 */


#pragma mark-
#pragma mark Observer methods

/*
    These are called by data layer to notify that more information about an item has become available from the server
 */

-(void) notifyItemAvailable:(ZPZoteroItem*) item{
    
    if([item.key isEqualToString:_currentItem.key]){
        _currentItem = item;
        [_activityIndicator startAnimating];
        [self performSelectorOnMainThread:@selector( _reconfigureAttachmentsCarousel) withObject:nil waitUntilDone:YES];
        [self performSelectorOnMainThread:@selector( _reconfigureDetailTableView) withObject:nil waitUntilDone:YES];
        [_activityIndicator stopAnimating];

    }
}

-(void) notifyAttachmentDownloadCompleted:(ZPZoteroAttachment*) attachment{
    ZPZoteroAttachment* thisAttachment;
    NSInteger index=0;
    for(thisAttachment in _currentItem.attachments){
        if([attachment isEqual:thisAttachment]){
            //It is possible that we have new items from this view
            [_activityIndicator startAnimating];
            if([_carouselViews count] <= index) [self performSelectorOnMainThread:@selector( _reconfigureAttachmentsCarousel) withObject:nil waitUntilDone:YES];
            [_previewController configurePreview:[_carouselViews objectAtIndex:index] withAttachment:attachment];
            [_activityIndicator stopAnimating];
        }
        index++;
    }
}


#pragma mark -
#pragma mark iCarousel methods

//Show the currently selected item in quicklook if tapped

- (void)carousel:(iCarousel *)carousel didSelectItemAtIndex:(NSInteger)index{
    if([carousel currentItemIndex] == index){
        
        
        ZPZoteroAttachment* attachment = [[_currentItem attachments] objectAtIndex:index];
        
        [_previewController openInQuickLookWithAttachment:attachment];
    }
}



- (NSUInteger)numberOfPlaceholdersInCarousel:(iCarousel *)carousel{
    return 0;
}

- (NSUInteger)numberOfItemsInCarousel:(iCarousel *)carousel
{
    if(_currentItem.attachments == NULL) return 0;
    else return [_currentItem.attachments count];
}


- (NSUInteger) numberOfVisibleItemsInCarousel:(iCarousel*)carousel{
    NSInteger numItems = [self numberOfItemsInCarousel:carousel];
    NSInteger ret=  MAX(numItems,5);
    return ret;
}

- (UIView *)carousel:(iCarousel *)carousel viewForItemAtIndex:(NSUInteger)index
{
    
    return [_carouselViews objectAtIndex:index];
}

#pragma mark -

@end
