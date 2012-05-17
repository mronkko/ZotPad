//
//  ZPItemDetailViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/4/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPCore.h"

#import "ZPItemDetailViewController.h"
#import "ZPLibraryAndCollectionListViewController.h"
#import "ZPItemListViewController.h"
#import "ZPItemListViewController.h"
#import "ZPDataLayer.h"
#import "ZPLocalization.h"
#import "ZPQuicklookController.h"
#import "ZPLogger.h"
#import "ZPAppDelegate.h"
#import "ZPServerConnection.h"
#import "ZPPreferences.h"
#import "ZPAttachmentPreviewViewController.h"

//Define 

#define IPAD UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad

#define ATTACHMENT_VIEW_HEIGHT (IPAD ? 600 : 400)

@interface ZPItemDetailViewController(){
    NSMutableDictionary* _cachedViewControllers;
}

- (void) _reconfigureDetailTableView:(BOOL)animated;
- (void) _reconfigureCarousel;
- (NSString*) _textAtIndexPath:(NSIndexPath*)indexPath isTitle:(BOOL)isTitle;

- (BOOL) _useAbstractCell:(NSIndexPath*)indexPath;
    
-(void) _reloadAttachmentInCarousel:(ZPZoteroItem*)attachment;
-(void) _reloadCarouselItemAtIndex:(NSInteger) index;

-(CGRect)_getDimensionsWithImage:(UIImage*) image; 

@end

@implementation ZPItemDetailViewController


@synthesize selectedItem = _currentItem;

#pragma mark - View lifecycle



- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[ZPDataLayer instance] registerItemObserver:self];

    //configure carousel
    _carousel = [[iCarousel alloc] initWithFrame:CGRectMake(0,0, 
                                                            self.view.frame.size.width,
                                                            ATTACHMENT_VIEW_HEIGHT)];
    _carousel.type = iCarouselTypeCoverFlow2;    
    [_carousel setDataSource:self];
    [_carousel setDelegate:self];
    
    self.tableView.tableHeaderView = _carousel;

    //Configure activity indicator.
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0,0,20, 20)];
    [_activityIndicator hidesWhenStopped];
    UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
    self.navigationItem.rightBarButtonItem = barButton;

    _cachedViewControllers = [[NSMutableDictionary alloc] init];
}

- (void)viewWillAppear:(BOOL)animated
{

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        //Set self as a delegate for the navigation controller so that we know when the view is being dismissed by the navigation controller and know to pop the other navigation controller.
        [self.navigationController setDelegate:self];
    }
    
    [super viewWillAppear:animated];

}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    
    [[ZPDataLayer instance] removeItemObserver:self];
    
	[super viewWillDisappear:animated];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    [_previewCache removeAllObjects];
}

#pragma mark - Configure view and subviews

-(void) configure{
    
    if([ZPServerConnection instance]!=NULL){
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
    if([_currentItem.attachments count]==0){
        [_carousel setHidden:TRUE];
    }
    else{
        [_carousel setHidden:FALSE];
        [_carousel setScrollEnabled:[_currentItem.attachments count]>1];
        [_carousel performSelectorOnMainThread:@selector(reloadData) withObject:NULL waitUntilDone:NO];
    }
}


- (void)_reconfigureDetailTableView:(BOOL)animated{
    
    //Configure the size of the detail view table.
    
    [self.tableView reloadData];
    [self.tableView layoutIfNeeded];
    
}


#pragma mark - Navigation controller delegate

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated{
    
    if(viewController != self){
        //Pop the other controller if something else than self is showing
        ZPAppDelegate* appDelegate = (ZPAppDelegate*)[[UIApplication sharedApplication] delegate];
        
        [[[(UISplitViewController*)appDelegate.window.rootViewController viewControllers] objectAtIndex:0] popViewControllerAnimated:YES];
        
        //Remove delegate because we no longer need to pop the other controller
        [navigationController setDelegate:NULL];
    }
}

/*
 
 sections
 1) Type and title
 2) Creators
 3) Other details
 

*/

#pragma mark - Tableview delegate

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
    if(tableView==self.tableView && [self _useAbstractCell:indexPath]){
        
        NSString *text = [self _textAtIndexPath:indexPath isTitle:false];

        NSInteger textWidth;
 
        //Margins includes margins and title.

        NSInteger margins=110;
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)) textWidth=663;
            else textWidth = 678;
        }
        else{
            if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)){
                textWidth = 460;
            }
            else{
                textWidth = 300;   
            }
        }

        CGSize textSize = [text sizeWithFont:[UIFont systemFontOfSize:14]
                           constrainedToSize:CGSizeMake(textWidth, 1000.0f)];
        
        
        return textSize.height+margins;
       
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
            else return [ZPLocalization getLocalizationStringWithKey:_currentItem.itemType  type:@"itemType" ];
        }
        
    }
    //Creators
    else if([indexPath indexAtPosition:0] == 1){
        NSDictionary* creator=[_currentItem.creators objectAtIndex:indexPath.row];
        if(isTitle) return [ZPLocalization getLocalizationStringWithKey:[creator objectForKey:@"creatorType"] type:@"creatorType" ];
        else{
            NSString* lastName = [creator objectForKey:@"lastName"];
            if(lastName==NULL || lastName==[NSNull null] || [lastName isEqualToString:@""]){
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
        
        if(isTitle) return [ZPLocalization getLocalizationStringWithKey:key  type:@"field" ];
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
        UILabel* textView = (UILabel*) [cell viewWithTag:2];
        textView.text = [self _textAtIndexPath:indexPath isTitle:FALSE];
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
	return  cell;
}


- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Item details
    
    if(aTableView == self.tableView){
        
    }
    
    // Navigator
    else{
        // Get the key for the selected item 
        NSArray* itemArray =[(ZPItemListViewController*) aTableView.dataSource itemKeysShown];
        if(indexPath.row<[itemArray count]){                    
            NSString* currentItemKey = [itemArray objectAtIndex: indexPath.row]; 
            
            if((NSObject*)currentItemKey != [NSNull null]){
                _currentItem = (ZPZoteroItem*) [ZPZoteroItem dataObjectWithKey:currentItemKey];
                [self configure];
            }
            
        }
    }
}




#pragma mark - iCarousel delegate


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

- (UIView *)carousel:(iCarousel *)carousel viewForItemAtIndex:(NSUInteger)index reusingView:(UIView*)view
{
    ZPAttachmentPreviewViewController* attachmentViewController;
    
    if(view==NULL){
        UIStoryboard *storyboard = self.storyboard;
        attachmentViewController = [storyboard instantiateViewControllerWithIdentifier:@"AttachmentPreview"];
        @synchronized(_cachedViewControllers){
            [_cachedViewControllers setObject:attachmentViewController forKey:[NSNumber numberWithInt:view]];
        }
    }
    else{
        @synchronized(_cachedViewControllers){
            attachmentViewController = [_cachedViewControllers objectForKey:[NSNumber numberWithInt:view]];
        }
    }

    attachmentViewController.attachment= [_currentItem.attachments objectAtIndex:index];
    attachmentViewController.allowDownloading = TRUE;
    attachmentViewController.usePreview = TRUE;
    attachmentViewController.showLabel = TRUE;
    return attachmentViewController.view;
}

//This is implemented because it is a mandatory protocol method
- (UIView *)carousel:(iCarousel *)carousel placeholderViewAtIndex:(NSUInteger)index reusingView:(UIView *)view{
    return view;
}

- (void)carousel:(iCarousel *)carousel didSelectItemAtIndex:(NSInteger)index{
    if([carousel currentItemIndex] == index){
        
        ZPZoteroAttachment* attachment = [_currentItem.attachments objectAtIndex:index]; 
        
        if([attachment fileExists] ||
           ([attachment.linkMode intValue] == LINK_MODE_LINKED_URL && [ZPServerConnection instance])){
            UIView* sourceView;
            for(sourceView in _carousel.visibleItemViews){
                if([carousel indexOfItemView:sourceView] == index) break;
            }
            [[ZPQuicklookController instance] openItemInQuickLook:attachment sourceView:sourceView];
        }
        else if([attachment.linkMode intValue] == LINK_MODE_IMPORTED_FILE || 
                [attachment.linkMode intValue] == LINK_MODE_IMPORTED_URL){
            
            ZPServerConnection* connection = [ZPServerConnection instance];
            
            
            if(connection!=NULL && ! [connection isAttachmentDownloading:attachment]){
                NSLog(@"Started downloading file %@ in index %i",attachment.title,index);
                [connection checkIfCanBeDownloadedAndStartDownloadingAttachment:attachment];   
            }
            
        }

    }
}

#pragma mark - Observer methods

/*
 These are called by data layer to notify that more information about an item has become available from the server
 */

-(void) notifyItemAvailable:(ZPZoteroItem*) item{
    
    if([item.key isEqualToString:_currentItem.key]){
        _currentItem = item;
        [_activityIndicator startAnimating];
        if([_carousel numberOfItems]!= item.attachments.count){
// This used to be animated, but it is now simply always displayed
            //            [UIView animateWithDuration:0.5 animations:^{
                [self _reconfigureCarousel];
//          }];
        }
        [self performSelectorOnMainThread:@selector(_reconfigureDetailTableView:) withObject:[NSNumber numberWithBool:TRUE] waitUntilDone:NO];
        
        [_activityIndicator stopAnimating];
        
    }
}

-(void) _reloadAttachmentInCarousel:(ZPZoteroItem*)attachment {
    NSInteger index = [_currentItem.attachments indexOfObject:attachment];
    if(index !=NSNotFound){
        [self performSelectorOnMainThread:@selector(_reloadCarouselItemAtIndex:) withObject:[NSNumber numberWithInt:index] waitUntilDone:YES];
    }
}

-(void) _reloadCarouselItemAtIndex:(NSInteger) index{
    [_carousel reloadItemAtIndex:index animated:YES];
}

@end
