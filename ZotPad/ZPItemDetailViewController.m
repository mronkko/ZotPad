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

#define ATTACHMENT_VIEW_HEIGHT 700

#define ATTACHMENT_IMAGE_HEIGHT 600
#define ATTACHMENT_IMAGE_WIDTH 423

@interface ZPItemDetailViewController();

//@property (strong, nonatomic) UIPopoverController *masterPopoverController;

- (void) _reconfigureDetailTableViewAndAttachments;

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
    
    
    
    // Get the selected row from the item list
    NSIndexPath* indexPath = [[[ZPDetailedItemListViewController instance] tableView] indexPathForSelectedRow];
    
    // Get the key for the selected item 
    NSString* currentItemKey = [[[ZPDetailedItemListViewController instance] itemKeysShown] objectAtIndex: indexPath.row]; 
    
    [self configureWithItemKey: currentItemKey];
  
    //configure carousel
    _carousel.type = iCarouselTypeCoverFlow2;
    [_carousel reloadData];

}

- (void)viewWillAppear:(BOOL)animated
{
    
    
    //Configure attachment section. Attachment section will be always shown even if there are no attachments
    
    UIView* attachmentView = [self.view viewWithTag:2];
    [attachmentView setFrame:CGRectMake(0,0, 
                                        self.view.frame.size.width,
                                        ATTACHMENT_VIEW_HEIGHT)];
    
    
    //Show the item view in the navigator
  
    _itemListController = [self.storyboard instantiateViewControllerWithIdentifier:@"NavigationItemListView"];
    
    [_itemListController setItemKeysShown:[[ZPDetailedItemListViewController instance] itemKeysShown]];
    
    _itemListController.navigationItem.hidesBackButton = YES;
    
    
    [[[ZPLibraryAndCollectionListViewController instance] navigationController] pushViewController:_itemListController  animated:YES];

	[super viewWillAppear:animated];

    // Get the selected row from the item list
    NSIndexPath* indexPath = [[[ZPDetailedItemListViewController instance] tableView] indexPathForSelectedRow];
    
    //Set the selected row to match the current row
    [[_itemListController tableView] selectRowAtIndexPath:indexPath animated:FALSE scrollPosition:UITableViewScrollPositionMiddle];

    _detailTableView.scrollEnabled = FALSE;
    
    [_itemListController.tableView setDelegate: self];

}


/*
//This works, but looks ugly
 - (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
     UIView* attachmentView = [self.view viewWithTag:2];
     [attachmentView setFrame:CGRectMake(0,0, 
                                         self.view.frame.size.width,
                                         ATTACHMENT_VIEW_HEIGHT)];  
     [_detailTableView setFrame:CGRectMake(0, 
                                           ATTACHMENT_VIEW_HEIGHT, 
                                           self.view.frame.size.width, 
                                           [_detailTableView contentSize].height)];
 
}
*/


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
    
    _currentItem = [[ZPDataLayer instance] getItemByKey: key];
    
    // If there is no detailed information available for this item, tell teh data layer to retrieve it
    if(_currentItem.fields == NULL || _currentItem.attachments == NULL || _currentItem.creators == NULL){
        [[ZPDataLayer instance] updateItemDetailsFromServer:_currentItem];
    }
    
    
    [self _reconfigureDetailTableViewAndAttachments ];
    
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

- (void)_reconfigureDetailTableViewAndAttachments {
    
    //Configure the size of the detail view table.
    
    [_detailTableView reloadData];
    
    [_detailTableView layoutIfNeeded];
    
    [_detailTableView setFrame:CGRectMake(0, 
                                          [self.view viewWithTag:2].frame.size.height, 
                                          self.view.frame.size.width, 
                                          [_detailTableView contentSize].height)];
   
    //TODO: possibly do this only if needed
    [_carousel reloadData];
    
    //Configure  the size of the UIScrollView
    [(UIScrollView*) self.view setContentSize:CGSizeMake(self.view.frame.size.width, [self.view viewWithTag:2].frame.size.height + [_detailTableView contentSize].height)];
    
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
        cell.textLabel.text = [ZPLocalization getLocalizationStringWithKey:key  type:@"field" locale:NULL];

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
        [self performSelectorOnMainThread:@selector( _reconfigureDetailTableViewAndAttachments) withObject:nil waitUntilDone:NO];
    }
}

-(void) notifyItemAttachmentInformationAvailable:(ZPZoteroItem*) item{
    
}

-(void) notifyItemAttachmentFileAvailable:(ZPZoteroItem*) item{
    
}


#pragma mark -
#pragma mark iCarousel methods

//Show the currently selected item in quicklook if tapped

- (void)carousel:(iCarousel *)carousel didSelectItemAtIndex:(NSInteger)index{
    if([carousel currentItemIndex] == index){
        [_previewController openInQuickLookWithAttachment:[[_currentItem attachments] objectAtIndex:index]];
    }
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
    UIView* view = [_previewController thumbnailAsUIImageView:index];
    
    NSString* extraInfo;
    ZPZoteroAttachment* attachment = [_currentItem.attachments objectAtIndex:index];
    
    if(![attachment fileExists] && ![attachment.attachmentType isEqualToString:@"application/pdf"]){
        if([attachment fileExists]){
            extraInfo = [@"Preview not supported for " stringByAppendingString:attachment.attachmentType];
        }
        else{
            extraInfo = @"Not downloaded";
        }
    }
    
    //Add information over the thumbnail
    
    UILabel* label = [[UILabel alloc] init];
    
    if(extraInfo!=NULL) label.text = [NSString stringWithFormat:@"%@ (%@)", attachment.attachmentTitle, extraInfo];
    else label.text = [NSString stringWithFormat:@"%@", attachment.attachmentTitle];
    
    label.textColor = [UIColor whiteColor];
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = UITextAlignmentCenter;
    label.lineBreakMode = UILineBreakModeWordWrap;
    label.numberOfLines = 5;
    label.frame=CGRectMake(50, 200, ATTACHMENT_IMAGE_WIDTH-100, ATTACHMENT_IMAGE_HEIGHT-400);
    
    UIView* background = [[UIView alloc] init];
    background.frame=CGRectMake(40, 190, ATTACHMENT_IMAGE_WIDTH-80, ATTACHMENT_IMAGE_HEIGHT-380);
    background.backgroundColor=[UIColor blackColor];
    background.alpha = 0.5;
    background.layer.cornerRadius = 8;

    [view addSubview:background];
    [view addSubview:label];
    
    return view;
}

#pragma mark -
/*

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
*/
@end
