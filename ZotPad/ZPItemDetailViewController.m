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

#import "ZPPreferences.h"

#define ATTACHMENT_VIEW_HEIGHT 680

#define ATTACHMENT_IMAGE_HEIGHT 600
#define ATTACHMENT_IMAGE_WIDTH 423

@interface ZPItemDetailViewController();
- (void) _reconfigureDetailTableView:(BOOL)animated;
- (void) _reconfigureCarousel;
- (NSString*) _textAtIndexPath:(NSIndexPath*)indexPath isTitle:(BOOL)isTitle;
- (BOOL) _useAbstractCell:(NSIndexPath*)indexPath;

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

    //TODO: This object should probably be recycled.
    
    _previewController = [[ZPFileThumbnailAndQuicklookController alloc] initWithItem:_currentItem viewController:self maxHeight:ATTACHMENT_IMAGE_HEIGHT maxWidth:ATTACHMENT_IMAGE_WIDTH];

    
    if([[ZPPreferences instance] online]){
        [_activityIndicator startAnimating];
        [[ZPDataLayer instance] updateItemDetailsFromServer:_currentItem];
    }
        

    
    [self _reconfigureDetailTableView:FALSE];
    [self _reconfigureCarousel];



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
    

}
- (void) _reconfigureCarousel{
    if([_currentItem.attachments count]==0) [_carousel setHidden:TRUE];
    else{
        [_carousel setHidden:FALSE];
        [_carousel setScrollEnabled:[_currentItem.attachments count]>1];
        
        NSMutableArray* tempArray = [[NSMutableArray alloc] init];
        
        for(ZPZoteroAttachment* attachment in _currentItem.attachments){
            UIView* view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ATTACHMENT_IMAGE_WIDTH, ATTACHMENT_IMAGE_HEIGHT)];
            [_previewController configurePreview:view withAttachment:attachment];
            [tempArray addObject:view];
        }
        _carouselViews =  tempArray;
        [_carousel reloadData];
    }
    
}


- (void)_reconfigureDetailTableView:(BOOL)animated{
    
    //Configure the size of the detail view table.
    
    
    [_detailTableView reloadData];

    UILabel* label= [self tableView:_detailTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].textLabel;

    _detailTitleWidth = 0;

    for(NSString* key in _currentItem.fields){
        NSInteger fittedWidth = [key sizeWithFont:label.font].width;
        if(fittedWidth > _detailTitleWidth){
            _detailTitleWidth = fittedWidth;
        }
    }

    [_detailTableView layoutIfNeeded];
    
    CGFloat contentHeight = _detailTableView.contentSize.height;
    
    if(animated){
        [UIView animateWithDuration:0.5 animations:^{
            [_detailTableView setFrame:CGRectMake(0, 
                                                  ([_currentItem.attachments count]>0)*ATTACHMENT_VIEW_HEIGHT, 
                                                  self.view.frame.size.width, 
                                                  [_detailTableView contentSize].height)];
            
            
            [(UIScrollView*) self.view setContentSize:CGSizeMake(self.view.frame.size.width, ([_currentItem.attachments count]>0)*ATTACHMENT_VIEW_HEIGHT + contentHeight)];
        }];
    }
    else{
        [_detailTableView setFrame:CGRectMake(0, 
                                              ([_currentItem.attachments count]>0)*ATTACHMENT_VIEW_HEIGHT, 
                                              self.view.frame.size.width, 
                                              [_detailTableView contentSize].height)];
        
        
        [(UIScrollView*) self.view setContentSize:CGSizeMake(self.view.frame.size.width, ([_currentItem.attachments count]>0)*ATTACHMENT_VIEW_HEIGHT + contentHeight)];

    }
    
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



- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{

    //Abstract is treated a bit differently
    if(tableView==_detailTableView && [self _useAbstractCell:indexPath]){
        
        NSString *text = [self _textAtIndexPath:indexPath isTitle:false];
        CGSize textSize = [text sizeWithFont:[UIFont systemFontOfSize:14]
                           constrainedToSize:CGSizeMake(_detailTableView.frame.size.width-100, 1000.0f)];
        
        return textSize.height + 100;
       
    }
    return tableView.rowHeight;
}

- (BOOL) _useAbstractCell:(NSIndexPath*)indexPath{
    if([indexPath indexAtPosition:0] != 2) return FALSE;
    
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
    
    return [key isEqualToString:@"abstractNote"];
    
}

- (NSString*) _textAtIndexPath:(NSIndexPath*)indexPath isTitle:(BOOL)isTitle{

    
    //Title and itemtype

    if([indexPath indexAtPosition:0] == 0){
        if(indexPath.row == 0){
            if(isTitle) return @"Title";
            else return _currentItem.title;
        }
        if(indexPath.row == 1){
            if(isTitle) return @"Item type";
            else return [ZPLocalization getLocalizationStringWithKey:_currentItem.itemType  type:@"itemType" locale:NULL];
        }
        
    }
    //Creators
    else if([indexPath indexAtPosition:0] == 1){
        NSDictionary* creator=[_currentItem.creators objectAtIndex:indexPath.row];
        if(isTitle) return [ZPLocalization getLocalizationStringWithKey:[creator objectForKey:@"creatorType"] type:@"creatorType" locale:NULL];
        else{
            NSString* lastName = [creator objectForKey:@"lastName"];
            if(lastName==NULL || [lastName isEqualToString:@""]){
                return [creator objectForKey:@"shortName"];
            }
            else{
                return [NSString stringWithFormat:@"%@ %@",[creator objectForKey:@"firstName"],lastName];
            }

        }
    }
    //Rest of the fields
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
        
        if(isTitle) return [ZPLocalization getLocalizationStringWithKey:key  type:@"field" locale:NULL];
        else return [_currentItem.fields objectForKey:key];
    }
}


 
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell;
    
    if([self _useAbstractCell:indexPath]){
        NSString* CellIdentifier = @"ItemAbstractCell";        
        
        // Dequeue or create a cell of the appropriate type.
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        }
        
        // Configure the cell
        UITextView* textView = (UITextView*) [cell viewWithTag:2];
        textView.text = [self _textAtIndexPath:indexPath isTitle:FALSE];
        textView.frame= CGRectMake(textView.frame.origin.x, textView.frame.origin.y, textView.frame.size.width, [self tableView:tableView heightForRowAtIndexPath:indexPath]-50);
        
    }
    else {
        NSString* CellIdentifier = @"ItemDetailCell";        
        
        // Dequeue or create a cell of the appropriate type.
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        }
        
        // Configure the cell
        cell.textLabel.text = [self _textAtIndexPath:indexPath isTitle:TRUE];
        cell.detailTextLabel.text = [self _textAtIndexPath:indexPath isTitle:FALSE];
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

        [self _reconfigureCarousel];
        [self performSelectorOnMainThread:@selector(_reconfigureDetailTableView:) withObject:[NSNumber numberWithBool:TRUE] waitUntilDone:YES];

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
            //TODO: Smarter reloading. Do inserts and reloads on a view level instead
            [_carousel reloadData];
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
