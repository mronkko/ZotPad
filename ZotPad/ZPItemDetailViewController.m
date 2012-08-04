//
//  ZPItemDetailViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/4/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "ZPItemDetailViewController.h"
#import "ZPLibraryAndCollectionListViewController.h"
#import "ZPItemListViewDataSource.h"
#import "ZPDataLayer.h"
#import "ZPLocalization.h"
#import "ZPAttachmentFileInteractionController.h"
#import "ZPPreviewController.h"

#import "ZPAppDelegate.h"
#import "ZPServerConnection.h"
#import "ZPPreferences.h"
#import "ZPAttachmentIconImageFactory.h"
#import "ZPAttachmentCarouselDelegate.h"
#import "OHAttributedLabel.h"

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
-(NSInteger) _textWidth;

@end

@implementation ZPItemDetailViewController


@synthesize selectedItem = _currentItem;
@synthesize actionButton;

#pragma mark - View lifecycle



- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if(_carouselDelegate == NULL){
        _carouselDelegate = [[ZPAttachmentCarouselDelegate alloc] init];
        _carouselDelegate.mode = ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD;
        _carouselDelegate.show = ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_MODIFIED;
        _carouselDelegate.owner = self;
        
    }
    else if(self.selectedItem != NULL){
        [_carouselDelegate configureWithZoteroItem:_currentItem];
        self.navigationItem.title=_currentItem.shortCitation;
    }
    //configure carousel
    _carousel = [[iCarousel alloc] initWithFrame:CGRectMake(0,0, 
                                                            self.view.frame.size.width,
                                                            ATTACHMENT_VIEW_HEIGHT)];
    _carousel.type = iCarouselTypeCoverFlow2;
    _carouselDelegate.actionButton=self.actionButton;
    _carouselDelegate.attachmentCarousel = _carousel;

    
    [_carousel setDataSource:_carouselDelegate];
    [_carousel setDelegate:_carouselDelegate];

    _carousel.bounces = FALSE;

    _carousel.currentItemIndex = _carouselDelegate.selectedIndex;
    
    self.tableView.tableHeaderView = _carousel;

    //Configure activity indicator.
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0,0,20, 20)];
    [_activityIndicator hidesWhenStopped];
    UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:self.actionButton, barButton, nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyItemAvailable:) 
                                                 name:@"ItemDataAvailable"
                                               object:nil];


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

-(void) dealloc{
   [[NSNotificationCenter defaultCenter] removeObserver:self];
}
-(void)viewDidUnload{
    _activityIndicator = NULL;
    _carouselDelegate.attachmentCarousel = NULL;
    _carousel = NULL;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewDidUnload];
}

- (void)didReceiveMemoryWarning
{
    [_previewCache removeAllObjects];
    [super didReceiveMemoryWarning];
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
    
    // This if is needed to protect agains a crash where the _carousel currentItemIndex is MAXINT and there are no attachments.
    
    if(_carousel.currentItemIndex < [_currentItem.attachments count]){
        ZPZoteroAttachment* currentAttachment = [_currentItem.attachments objectAtIndex:[_carousel currentItemIndex]];
        if(_attachmentInteractionController == NULL)  _attachmentInteractionController = [[ZPAttachmentFileInteractionController alloc] init];
        [_attachmentInteractionController setAttachment:currentAttachment];
        [_attachmentInteractionController presentOptionsMenuFromBarButtonItem:sender];
    }
    
    // And this else for diagnosing the crash. Once the root cause is identified, these can be removed
    else{
        DDLogError(@"Attempting to open action menu for attachment in index %i for an item with %i attachments. The item key is %@ and full citation is %@",
                   _carousel.currentItemIndex,_currentItem.attachments.count,_currentItem.key,_currentItem.fullCitation);
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
    if(tableView==self.tableView && [self _useAbstractCell:indexPath]){
        
        NSString *text = [self _textAtIndexPath:indexPath isTitle:false];

        //Margins includes margins and title.

        NSInteger margins=110;
        


        CGSize textSize = [text sizeWithFont:[UIFont systemFontOfSize:14]
                           constrainedToSize:CGSizeMake([self _textWidth], 1000.0f)];
        
        
        return textSize.height+margins;
       
    }
    return tableView.rowHeight;
}

-(NSInteger) _textWidth{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)) return 663;
        else return  678;
    }
    else{
        if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)){
            return  460;
        }
        else{
            return  300;   
        }
    }    
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


    NSString* returnString = NULL;
    
    //Title and itemtype

    if([indexPath indexAtPosition:0] == 0){
        if(indexPath.row == 0){
            if(isTitle) returnString =  @"Title";
            else returnString =  _currentItem.title;
        }
        if(indexPath.row == 1){
            if(isTitle) returnString =  @"Item type";
            else returnString =  [ZPLocalization getLocalizationStringWithKey:_currentItem.itemType  type:@"itemType" ];
        }
        
    }
    //Creators
    else if([indexPath indexAtPosition:0] == 1){
        NSDictionary* creator=[_currentItem.creators objectAtIndex:indexPath.row];
        if(isTitle) returnString =  [ZPLocalization getLocalizationStringWithKey:[creator objectForKey:@"creatorType"] type:@"creatorType" ];
        else{
            NSString* lastName = [creator objectForKey:@"lastName"];
            if(lastName==NULL || lastName==[NSNull null] || [lastName isEqualToString:@""]){
                returnString =  [creator objectForKey:@"shortName"];
            }
            else{
                returnString =  [NSString stringWithFormat:@"%@ %@",[creator objectForKey:@"firstName"],lastName];
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
        
        if(isTitle) returnString =  [ZPLocalization getLocalizationStringWithKey:key  type:@"field" ];
        else returnString =  [_currentItem.fields objectForKey:key];
    }
    
    //Validity checks
    if(returnString == NULL || returnString == [NSNull null]){
        DDLogError(@"Item %@ had an empty string (%@) as field %@ in section %i, row %i of the item details table.",_currentItem.key,
                   returnString==NULL ? @"nil" : @"NSNull",
                   isTitle ? @"title" : @"value",
                   indexPath.section,indexPath.row);
        
        returnString = @"";
    }
    
    return returnString;
}


 
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell;
    NSString* CellIdentifier;
    
    BOOL isAbstract = [self _useAbstractCell:indexPath];

    if(isAbstract){
        CellIdentifier = @"ItemAbstractCell";        
    }
    else {
        CellIdentifier = @"ItemDetailCell";        
    }

    // Dequeue or create a cell of the appropriate type.
    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }

    // Configure the cell
    OHAttributedLabel* value = (OHAttributedLabel*) [cell viewWithTag:2];
    UILabel* title = (UILabel*) [cell viewWithTag:1];
    
    value.text = [self _textAtIndexPath:indexPath isTitle:FALSE];
    title.text = [self _textAtIndexPath:indexPath isTitle:TRUE];

    //Configure size of the value label
    
    if(!isAbstract){
        CGSize labelSize = [title.text sizeWithFont:title.font];
        CGRect frame = value.frame;
        
        NSInteger newWidth = cell.contentView.bounds.size.width - labelSize.width - 40; 
        NSInteger widthChange = newWidth - value.frame.size.width;
        frame.size.width = newWidth; 
        frame.origin.x = frame.origin.x - widthChange;
        value.frame = frame;
    }
    
    if(cell == NULL || ! [cell isKindOfClass:[UITableViewCell class]]){
        [NSException raise:@"Invalid cell" format:@""];
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
        NSArray* itemArray =[(ZPItemListViewDataSource*) aTableView.dataSource itemKeysShown];
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

-(void) notifyItemAvailable:(NSNotification*) notification{
    
    ZPZoteroItem* item = [notification.userInfo objectForKey:@"item"];
    
    if([item.key isEqualToString:_currentItem.key]){
        _currentItem = item;
        [self performSelectorOnMainThread:@selector(_reconfigureDetailTableView:) withObject:[NSNumber numberWithBool:TRUE] waitUntilDone:NO];

        //If we had the activity indicator animating, stop it now because we are no longer waiting for data
        [_activityIndicator stopAnimating];
        
    }
}

@end
