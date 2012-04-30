//
//  ZPItemDetailViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/4/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

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
@synthesize detailTableView = _detailTableView;
@synthesize carousel = _carousel;

#pragma mark - View lifecycle



- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[ZPDataLayer instance] registerItemObserver:self];

    _detailTableView.scrollEnabled = FALSE;
    
    //configure carousel
    _carousel.type = iCarouselTypeCoverFlow2;    

    //Configure attachment section.     
    UIView* attachmentView = [self.view viewWithTag:2];
    [attachmentView setFrame:CGRectMake(0,0, 
                                        self.view.frame.size.width,
                                        ATTACHMENT_VIEW_HEIGHT)];

    //Configure activity indicator.
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0,0,20, 20)];
    [_activityIndicator hidesWhenStopped];
    UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
    self.navigationItem.rightBarButtonItem = barButton;

    _cachedViewControllers = [[NSMutableDictionary alloc] init];
}

- (void)viewWillAppear:(BOOL)animated
{
    //We need the dimensions of the view to be set before reconfiguring.
    [self configure];

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

-(void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{

    //Start with the frame for the carousel
    CGRect contentRect = _carousel.frame;
    
    contentRect.size.height = contentRect.size.height + [_detailTableView contentSize].height;;
    
    [(UIScrollView*)self.view setContentSize: contentRect.size];
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
    if([_currentItem.attachments count]==0) [_carousel setHidden:TRUE];
    else{
        [_carousel setHidden:FALSE];
        [_carousel setScrollEnabled:[_currentItem.attachments count]>1];
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
        [_detailTableView setNeedsDisplay];
    }
    
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
    if(tableView==_detailTableView && [self _useAbstractCell:indexPath]){
        
        NSString *text = [self _textAtIndexPath:indexPath isTitle:false];

        //The view has small margins
        NSInteger textWidth;
        NSInteger margins;
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            margins=10;
            if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)) textWidth=500;
            else textWidth = 500;
        }
        else{
            margins=100;
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
        UITextView* textView = (UITextView*) [cell viewWithTag:2];
        textView.text = [self _textAtIndexPath:indexPath isTitle:FALSE];
        //textView.frame= CGRectMake(textView.frame.origin.x, textView.frame.origin.y, textView.frame.size.width, [self tableView:tableView heightForRowAtIndexPath:indexPath]-50);
        
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
        NSLog(@"Instantiated attahcment view controller %x",attachmentViewController);
    }
    else{
        @synchronized(_cachedViewControllers){
            attachmentViewController = [_cachedViewControllers objectForKey:[NSNumber numberWithInt:view]];
        }
        NSLog(@"Instantiated attahcment view controller %x",attachmentViewController);
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
        
        if([attachment fileExists]) [[ZPQuicklookController instance] openItemInQuickLook:attachment sourceView:self];
        else{
            ZPServerConnection* connection = [ZPServerConnection instance];
            
            if(connection!=NULL && ! [connection isAttachmentDownloading:attachment]){
                [connection startDownloadingAttachment:attachment];   
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
            [self _reconfigureCarousel];
            [_carousel performSelectorOnMainThread:@selector(reloadData) withObject:NULL waitUntilDone:NO];
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
