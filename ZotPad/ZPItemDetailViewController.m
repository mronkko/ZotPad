//
//  ZPItemDetailViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/4/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

//TODO: Clean headers that are not needed

#import "ZPItemDetailViewController.h"
#import "ZPLibraryAndCollectionListViewController.h"
#import "ZPItemList.h"
#import "ZPLocalization.h"
#import "ZPAttachmentFileInteractionController.h"
#import "ZPNoteEditingViewController.h"
#import "ZPAppDelegate.h"
#import "NSString_stripHtml.h"
#import "ZPAttachmentIconImageFactory.h"
#import "ZPAttachmentCarouselDelegate.h"
#import "OHAttributedLabel.h"
#import "ZPStarBarButtonItem.h"
#import "ZPTagController.h"
#import "CMPopTipView.h"
#import "ZPTagEditingViewController.h"
#import "ZPItemDataDownloadManager.h"
#import "ZPReachability.h"
#import <UIKit/UIKit.h>

//Define 

#define IPAD UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad

#define ATTACHMENT_VIEW_HEIGHT (IPAD ? 600 : 400)

@interface ZPItemDetailViewController(){
    ZPAttachmentFileInteractionController* _attachmentInteractionController;
    ZPAttachmentCarouselDelegate* _carouselDelegate;
    NSArray* _tagButtons;

}

- (void) _reconfigureDetailTableView:(BOOL)animated;
- (NSString*) _textAtIndexPath:(NSIndexPath*)indexPath isTitle:(BOOL)isTitle;
- (BOOL) _useAbstractCell:(NSIndexPath*)indexPath;
//-(CGRect) _getDimensionsWithImage:(UIImage*) image;
-(NSInteger) _textWidth;

@end

@implementation ZPItemDetailViewController


@synthesize selectedItem = _currentItem;
@synthesize actionButton, starButton;

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
    UIBarButtonItem* activityIndicator = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
    self.starButton = [[ZPStarBarButtonItem alloc] init];
    
    //Show tool tip about stars
    
    if([[NSUserDefaults standardUserDefaults] objectForKey:@"hasPresentedStarButtonHelpPopover"]==NULL){
        CMPopTipView* helpPopUp = [[CMPopTipView alloc] initWithMessage:@"Use the star button to add an item to favourites"];
        [helpPopUp presentPointingAtBarButtonItem:starButton animated:YES];
        [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:@"hasPresentedStarButtonHelpPopover"];
    }

    
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:self.actionButton, self.starButton, activityIndicator, nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyItemAvailable:) 
                                                 name:ZPNOTIFICATION_ITEMS_AVAILABLE
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
    [_carouselDelegate unregisterProgressViewsBeforeUnloading];
}
- (void) viewWillUnload{
    [super viewWillUnload];
    [_carouselDelegate unregisterProgressViewsBeforeUnloading];
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
    
    if([ZPReachability hasInternetConnection]){
        //Animate until we get fresh data
        [_activityIndicator startAnimating];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ACTIVE_ITEM_CHANGED object:_currentItem];
    
    [self _reconfigureDetailTableView:FALSE];
    [_carouselDelegate configureWithZoteroItem:_currentItem];
    [_carousel reloadData];
    [self.starButton configureWithItem:_currentItem];
    self.navigationItem.title=_currentItem.shortCitation;
    
}

- (void)_reconfigureDetailTableView:(BOOL)animated{

    //Configure the size of the detail view table.
    _tagButtons = NULL;
    [self.tableView reloadData];
    [self.tableView layoutIfNeeded];
    
}
#pragma mark - Viewing and emailing

- (IBAction) actionButtonPressed:(id)sender{

    if(_attachmentInteractionController == NULL)  _attachmentInteractionController = [[ZPAttachmentFileInteractionController alloc] init];
    
    [_attachmentInteractionController setItem:_currentItem];
                                                                                      
    // If there are no attachments show the lookup menu
    
    if([_currentItem.attachments count] == 0){
        [_attachmentInteractionController setAttachment:nil];
        [_attachmentInteractionController presentLookupMenuFromBarButtonItem:sender];
    }
    
    // This is needed to protect agains a crash where the _carousel currentItemIndex is MAXINT and there are no attachments.
    
    else if(_carousel.currentItemIndex < [_currentItem.attachments count]){
        ZPZoteroAttachment* currentAttachment = [_currentItem.attachments objectAtIndex:[_carousel currentItemIndex]];
        if([currentAttachment fileExists]){
            [_attachmentInteractionController setAttachment:currentAttachment];
            [_attachmentInteractionController presentOptionsMenuFromBarButtonItem:sender];
        }
        else{
            [_attachmentInteractionController setAttachment:nil];
            [_attachmentInteractionController presentLookupMenuFromBarButtonItem:sender];
        }

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

#pragma mark - Tableview data source 

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
    return 5;
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    //Tags
    if(section==0){
        return 1;
    }
    //Notes
    if(section==1){
        return [_currentItem.notes count]+1;
    }
    
    //Item type and title
    if(section==2){
        return 2;
    }
    //Creators
    if(section==3){
        if(_currentItem.creators!=NULL || [_currentItem.itemType isEqualToString:ZPKEY_ATTACHMENT]|| [_currentItem.itemType isEqualToString:@"note"]){
            return [_currentItem.creators count];
        }
        else{
            return 0;
        }
    }
    //Rest of the fields
    if(section==4){
        if(_currentItem.fields!=NULL || [_currentItem.itemType isEqualToString:ZPKEY_ATTACHMENT]|| [_currentItem.itemType isEqualToString:@"note"]){
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
    //Tag cell
    else if(tableView==self.tableView && indexPath.section==0 && _tagButtons != NULL){
        //Get the size based on content
        NSInteger y=0;
        for(UIView* subView in _tagButtons){
            y=MAX(y,subView.frame.origin.y+subView.frame.size.height);
        }
        //Add a small margin to the bottom of the cell
        return MAX(y+7, tableView.rowHeight);
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
    if([indexPath indexAtPosition:0] != 4) return FALSE;
    
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

    if([indexPath indexAtPosition:0] == 2){
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
    else if([indexPath indexAtPosition:0] == 3){
        NSDictionary* creator=[_currentItem.creators objectAtIndex:indexPath.row];
        if(isTitle) returnString =  [ZPLocalization getLocalizationStringWithKey:[creator objectForKey:@"creatorType"] type:@"creatorType" ];
        else{
            NSObject* lastName = [creator objectForKey:@"lastName"];
            if(! [lastName isKindOfClass:[NSString class]] ||  [(NSString*)lastName isEqualToString:@""]){
                returnString =  [creator objectForKey:@"name"];
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
    if(returnString == NULL){
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
    
    //Tags
    if(indexPath.section == 0){
        if([_currentItem.tags count]==0){
            CellIdentifier = @"NoTagsCell";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil)
            {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            }
        }
        else{
            CellIdentifier = @"TagsCell";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil)
            {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            }
       
            //Clean the cell
            
            [ZPTagController addTagButtonsToView:cell.contentView tags:[NSArray array]];
            
            
            if(_tagButtons != NULL){
                for(UIView* tagButton in _tagButtons){
                    [cell.contentView addSubview:tagButton];
                }
            }
            
            _tagButtons = cell.contentView.subviews;
        }
    }
    //Notes
    else if([indexPath indexAtPosition:0] == 1){
        if([indexPath indexAtPosition:1]>=[_currentItem.notes count]){
            CellIdentifier = @"NewNoteCell";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil)
            {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            }
        }
        else{
            CellIdentifier = @"NoteCell";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil)
            {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            }
            UILabel* noteText = (UILabel*)[cell viewWithTag:1];
            noteText.text = [[[(ZPZoteroNote*) [_currentItem.notes objectAtIndex:[indexPath indexAtPosition:1]] note] stripHtml] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        }
    }
    //Item metadata
    else{
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
        value.automaticallyAddLinksForType = NSTextCheckingTypeLink;
        
        UILabel* title = (UILabel*) [cell viewWithTag:1];
        
        
        value.text = [self _textAtIndexPath:indexPath isTitle:FALSE];
        title.text = [self _textAtIndexPath:indexPath isTitle:TRUE];
        
        if([title.text isEqualToString:@"DOI"]){
            [value addCustomLink:[NSURL URLWithString:[@"http://dx.doi.org/" stringByAppendingString:value.text]] inRange:NSMakeRange(0,[value.text length])];
        }
        
        
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
    }
	return  cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if(section==0) return @"Tags";
    else if(section==1) return @"Notes";
    else if(section==2) return @"Item data";
    else return nil;
}

#pragma mark - UITableViewDelegate


// Populate the tags cells after they are displayed

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    
    //If we have a cell that should show tags, but does not, reload
    if(indexPath.section==0 && [_currentItem.tags count] > 0 && [cell.contentView.subviews count] == 0){
        
        //Add tags and reload
        [ZPTagController addTagButtonsToView:cell.contentView tags:_currentItem.tags];
        
        _tagButtons = cell.contentView.subviews;
        
        [tableView reloadData];
        
        // This is more efficient, but produces an unnecessary animation
        
        //[tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];

    }
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Item details
    
    if(aTableView == self.tableView){
        //Tags
        if([indexPath indexAtPosition:0]==0){
            if(_tagEditingViewController == NULL){
                _tagEditingViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"TagEditingViewController"];
            }
            _tagEditingViewController.item = _currentItem;
            [self presentModalViewController:_tagEditingViewController animated:YES];
        }
        //Notes
        else if([indexPath indexAtPosition:0]==1){
            ZPZoteroNote* note;
            if([indexPath indexAtPosition:1]>=[_currentItem.notes count]){
                note = [ZPZoteroNote noteWithKey:[NSString stringWithFormat:@"LOCAL_%@",[NSDate date]]];
                note.parentKey = _currentItem.key;
            }
            else{
                note = [_currentItem.notes objectAtIndex:[indexPath indexAtPosition:1]];
            }

            if(_noteEditingViewController == NULL){
                _noteEditingViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"NoteEditingViewController"];
            }
            _noteEditingViewController.note = note;

            [self presentModalViewController:_noteEditingViewController animated:YES];

        }
        [aTableView deselectRowAtIndexPath:indexPath animated:NO];
    }
    
    // Navigator
    else{
        // Get the key for the selected item 
        NSArray* itemArray =[(ZPItemListDataSource*) aTableView.dataSource contentArray];
        if(indexPath.row<[itemArray count]){                    
            NSString* currentItemKey = [itemArray objectAtIndex: indexPath.row]; 
            
            if((NSObject*)currentItemKey != [NSNull null]){
                _currentItem = (ZPZoteroItem*) [ZPZoteroItem itemWithKey:currentItemKey];
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
    
    ZPZoteroItem* item = [notification.userInfo objectForKey:ZPKEY_ITEM];
    
    if([item.key isEqualToString:_currentItem.key]){
        _currentItem = item;
        [self performSelectorOnMainThread:@selector(_reconfigureDetailTableView:) withObject:[NSNumber numberWithBool:TRUE] waitUntilDone:NO];

        //If we had the activity indicator animating, stop it now because we are no longer waiting for data
        [_activityIndicator stopAnimating];
        
    }
}

@end
