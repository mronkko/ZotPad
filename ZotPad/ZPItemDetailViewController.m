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
#import "ZPDataLayer.h"
#import "ZPLocalization.h"
#import "ZPAttachmentFileInteractionController.h"
#import "ZPPreviewController.h"

#import "ZPAppDelegate.h"
#import "ZPServerConnection.h"
#import "ZPPreferences.h"
#import "ZPAttachmentIconViewController.h"
#import "ZPAttachmentCarouselDelegate.h"

//Define 

#define IPAD UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad

#define ATTACHMENT_VIEW_HEIGHT (IPAD ? 600 : 400)

@interface ZPItemDetailViewController(){
    ZPAttachmentFileInteractionController* _attachmentInteractionController;
    ZPAttachmentCarouselDelegate* _carouselDelegate;
}

- (void) _reconfigureDetailTableView:(BOOL)animated;
- (NSString*) _textAtIndexPath:(NSIndexPath*)indexPath isTitle:(BOOL)isTitle;
- (BOOL) _useAbstractCell:(NSIndexPath*)indexPath;
-(CGRect) _getDimensionsWithImage:(UIImage*) image; 

@end

@implementation ZPItemDetailViewController


@synthesize selectedItem = _currentItem;
@synthesize actionButton;

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
    
    _carouselDelegate = [[ZPAttachmentCarouselDelegate alloc] init];
    _carouselDelegate.actionButton=self.actionButton;
    _carouselDelegate.attachmentCarousel = _carousel;
    _carouselDelegate.mode = ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD;
    _carouselDelegate.show = ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_MODIFIED;
    
    [_carousel setDataSource:_carouselDelegate];
    [_carousel setDelegate:_carouselDelegate];
    
    [[ZPDataLayer instance] registerAttachmentObserver:_carouselDelegate];
    [[ZPDataLayer instance] registerItemObserver:_carouselDelegate];

    self.tableView.tableHeaderView = _carousel;

    //Configure activity indicator.
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0,0,20, 20)];
    [_activityIndicator hidesWhenStopped];
    UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:self.actionButton, barButton, nil];

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
    [[ZPDataLayer instance] removeItemObserver:_carouselDelegate];
    [[ZPDataLayer instance] removeAttachmentObserver:_carouselDelegate];
    
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
    [_carouselDelegate configureWithZoteroItem:_currentItem];
    [_carousel reloadData];
    
    self.navigationItem.title=_currentItem.shortCitation;
    

}

- (void)_reconfigureDetailTableView:(BOOL)animated{
    
    //Configure the size of the detail view table.
    
    [self.tableView reloadData];
    [self.tableView layoutIfNeeded];
    
}
#pragma mark - Viewing and emailing

- (IBAction) actionButtonPressed:(id)sender{
    ZPZoteroAttachment* currentAttachment = [_currentItem.attachments objectAtIndex:[_carousel currentItemIndex]];
    if(_attachmentInteractionController == NULL)  _attachmentInteractionController = [[ZPAttachmentFileInteractionController alloc] init];
    [_attachmentInteractionController setAttachment:currentAttachment];
    [_attachmentInteractionController presentOptionsMenuFromBarButtonItem:sender];
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





#pragma mark - Observer methods

/*
 These are called by data layer to notify that more information about an item has become available from the server
 */

-(void) notifyItemAvailable:(ZPZoteroItem*) item{
    
    if([item.key isEqualToString:_currentItem.key]){
        _currentItem = item;
        [self performSelectorOnMainThread:@selector(_reconfigureDetailTableView:) withObject:[NSNumber numberWithBool:TRUE] waitUntilDone:NO];

        //If we had the activity indicator animating, stop it now because we are no longer waiting for data
        [_activityIndicator stopAnimating];
        
    }
}

@end
