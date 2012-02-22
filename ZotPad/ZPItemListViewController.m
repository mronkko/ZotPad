//
//  ZPDetailViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPItemListViewController.h"
#import "ZPDataLayer.h"
#import <QuartzCore/QuartzCore.h>
#import "../DSActivityView/Sources/DSActivityView.h"
#import "ZPLocalization.h"

//A helped class for setting sort buttons

@interface ZPItemListViewController_sortHelper: UITableViewController{
    UIPopoverController* _popover;
    UIButton* _targetButton;
    NSArray* _fieldTitles;
    NSArray* _fieldValues;
}

@property (retain) UIPopoverController* popover;
@property (retain) UIButton* targetButton;

@end

@implementation ZPItemListViewController_sortHelper

@synthesize popover = _popover;
@synthesize targetButton = _targetButton;

-(id) init{
    self=[super init];
    
    NSMutableArray* fieldTitles = [NSMutableArray array];
    NSArray* fieldValues = [[ZPDataLayer instance] fieldsThatCanBeUsedForSorting];
    
    for(NSString* value in fieldValues){
        [fieldTitles addObject:[ZPLocalization getLocalizationStringWithKey:value type:@"field"]];
    }
    
    _fieldTitles = [fieldTitles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    NSMutableArray* sortedFieldValues = [NSMutableArray array];
    
    for(NSString* title in _fieldTitles){
        [sortedFieldValues addObject:[fieldValues objectAtIndex:[fieldTitles indexOfObjectIdenticalTo:title]]];
    }
    
    _fieldValues = sortedFieldValues;
    
    return self;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell* cell = [[UITableViewCell alloc] init];
    cell.textLabel.text = [_fieldTitles objectAtIndex:indexPath.row];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [_fieldValues count];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    NSString* sortField = [_fieldValues objectAtIndex:indexPath.row];
    //Because this preference is not used anywhere else, it is accessed directly.
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:sortField forKey:[NSString stringWithFormat: @"itemListView_sortButton%i",_targetButton.tag]];

    UILabel* label = (UILabel*)[_targetButton.subviews objectAtIndex:1];
    
    [label setText:[ZPLocalization getLocalizationStringWithKey:sortField type:@"field"]];
    
    [_popover dismissPopoverAnimated:YES];
}

@end




@interface ZPItemListViewController ()
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@end

@implementation ZPItemListViewController

@synthesize collectionKey = _collectionKey;
@synthesize libraryID =  _libraryID;
@synthesize searchString = _searchString;
@synthesize sortField = _sortField;
@synthesize sortDescending = _sortDescending;

@synthesize masterPopoverController = _masterPopoverController;

@synthesize tableView = _tableView;
@synthesize searchBar = _searchBar;
@synthesize toolBar = _toolBar;

@synthesize itemKeysShown = _itemKeysShown;
@synthesize itemDetailViewController =  _itemDetailViewController;


#pragma mark - Managing the detail item

-(id) init{
    self = [super init];
    _cellCache = [[NSCache alloc] init];
    
    return self;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section. Initially there is no library selected, so we will just return an empty view
    if(_itemKeysShown==nil){
        return 0;
    }
    else{
        return [_itemKeysShown count];
    }
}


- (void)configureView
{
    // Update the user interface for the detail item.
    
    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }
    
    // Retrieve the item IDs if a library is selected. 
    
    if(_libraryID!=0){
        _itemKeysShown = [[ZPDataLayer instance] getItemKeysFromCacheForLibrary:_libraryID collection:_collectionKey searchString:_searchString orderField:_sortField sortDescending:_sortDescending];
        if(_itemKeysShown == NULL){
            [self makeBusy];
        }
        else{
            [self.tableView reloadData];
        }     
    }
}

//If we are not already displaying an activity view, do so now

- (void)makeBusy{
    if(_activityView==NULL){
        if([NSThread isMainThread]){
        [self.tableView setUserInteractionEnabled:FALSE];
        _activityView = [DSBezelActivityView newActivityViewForView:self.tableView];
        }
        else{
            [self performSelectorOnMainThread:@selector(notifyDataAvailable) withObject:nil waitUntilDone:NO];
        }   
    }
}

/*
 Called from data layer to notify that there is data for this view and it can be shown
 */

- (void)notifyDataAvailable{
    
    if([NSThread isMainThread]){
        [self.tableView reloadData];
        [DSBezelActivityView removeViewAnimated:YES];
        [self.tableView setUserInteractionEnabled:TRUE];
        _activityView = NULL;
    }
    else{
        [self performSelectorOnMainThread:@selector(notifyDataAvailable) withObject:nil waitUntilDone:NO];
    }
    
}

- (void)notifyItemAvailable:(NSString*) key{
    
    
    NSEnumerator *e = [[self.tableView indexPathsForVisibleRows] objectEnumerator];
    
    NSIndexPath* indexPath;
    while ((indexPath = (NSIndexPath*) [e nextObject]) && indexPath.row <=[_itemKeysShown count]) {
        if([key isEqualToString:[_itemKeysShown objectAtIndex:indexPath.row]]){
            
            //Tell this cell to update because it just got data
            
            [self performSelectorOnMainThread:@selector(_refreshCellAtIndexPaths:) withObject:[NSArray arrayWithObject:indexPath] waitUntilDone:NO];
            
            break;
        }
    }
}
- (void) _refreshCellAtIndexPaths:(NSArray*)indexPaths{
    [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];

}
- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

   
    
    NSObject* keyObj = [_itemKeysShown objectAtIndex: indexPath.row];


    
    NSString* key;
    if(keyObj==[NSNull null]){
        key=@"";
    }    
    else{
        key= (NSString*) keyObj;
    }    
    
	UITableViewCell* cell = [self->_cellCache objectForKey:key];
    
    if(cell==nil){
        
        //TODO: Set author and year to empty if not defined. 
        ZPZoteroItem* item=NULL;
        if(![key isEqualToString:@""]) item = (ZPZoteroItem*) [ZPZoteroItem dataObjectWithKey:key];
        
        if(item==NULL){
            cell = [aTableView dequeueReusableCellWithIdentifier:@"LoadingCell"];        
        }
        else{

            cell = [aTableView dequeueReusableCellWithIdentifier:@"ZoteroItemCell"];
            
            UILabel *titleLabel = (UILabel *)[cell viewWithTag:1];
            titleLabel.text = item.title;
            
            UILabel *authorsLabel = (UILabel *)[cell viewWithTag:2];
            
            //Show different things depending on what data we have
            if(item.creatorSummary!=NULL){
                if(item.date!= 0){
                    authorsLabel.text = [NSString stringWithFormat:@"%@ (%i)",item.creatorSummary,item.date];
                }
                else{
                    authorsLabel.text = [NSString stringWithFormat:@"%@ (No date)",item.creatorSummary];
                }
            }    
            else if(item.date!= 0){
                authorsLabel.text = [NSString stringWithFormat:@"No author (%i)",item.date];
            }

            //Publication as a formatted label

            NSString* publishedIn = item.publicationTitle;
            
            if(publishedIn == NULL){
                publishedIn=@"";   
            }
            
            //Does this cell already have a TTStyledTextLabel
            NSEnumerator* e = [[cell subviews] objectEnumerator];

            TTStyledTextLabel* publishedInLabel;

            NSObject* subView;
            while(subView = [e nextObject]){
                if([subView isKindOfClass:[TTStyledTextLabel class]]){
                    publishedInLabel = (TTStyledTextLabel*) subView;
                    break;
                }
            }
                  
            if(publishedInLabel == NULL){
                CGRect frame = CGRectMake(CGRectGetMinX(authorsLabel.frame),CGRectGetMaxY(authorsLabel.frame),CGRectGetWidth(cell.frame)-CGRectGetMinX(authorsLabel.frame),CGRectGetHeight(cell.frame)-CGRectGetMaxY(authorsLabel.frame)-2);
                publishedInLabel = [[TTStyledTextLabel alloc] 
                                            initWithFrame:frame];
                [publishedInLabel setFont:[UIFont systemFontOfSize:12]];
                [publishedInLabel setClipsToBounds:TRUE];
                [cell addSubview:publishedInLabel];
            }
            TTStyledText* text = [TTStyledText textFromXHTML:[publishedIn stringByReplacingOccurrencesOfString:@" & " 
                                                                                                    withString:@" &amp; "] lineBreaks:YES URLs:NO];
            [publishedInLabel setText:text];
            
            /*
             
             //Check if the item has attachments and render a thumbnail from the first attachment PDF
             
             NSArray* attachmentFilePaths = [[ZPDataLayer instance] getAttachmentFilePathsForItem: itemID];
             
             if([attachmentFilePaths count] > 0 ){
             UIImageView* articleThumbnail = (UIImageView *) [cell viewWithTag:4];
             
             NSLog(@"%@",[attachmentFilePaths objectAtIndex:0]);
             
             NSURL *pdfUrl = [NSURL fileURLWithPath:[attachmentFilePaths objectAtIndex:0]];
             CGPDFDocumentRef document = CGPDFDocumentCreateWithURL((__bridge_retained CFURLRef)pdfUrl);
             
             
             //
             // Renders a first page of a PDF as an image
             //
             // Source: http://stackoverflow.com/questions/5658993/creating-pdf-thumbnail-in-iphone
             //
             
             
             CGPDFPageRef pageRef = CGPDFDocumentGetPage(document, 1);
             CGRect pageRect = CGPDFPageGetBoxRect(pageRef, kCGPDFCropBox);
             
             UIGraphicsBeginImageContext(pageRect.size);
             CGContextRef context = UIGraphicsGetCurrentContext();
             CGContextTranslateCTM(context, CGRectGetMinX(pageRect),CGRectGetMaxY(pageRect));
             CGContextScaleCTM(context, 1, -1);  
             CGContextTranslateCTM(context, -(pageRect.origin.x), -(pageRect.origin.y));
             CGContextDrawPDFPage(context, pageRef);
             
             UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
             UIGraphicsEndImageContext();
             
             articleThumbnail.image = finalImage;
             [articleThumbnail.layer setBorderColor: [[UIColor blackColor] CGColor]];
             [articleThumbnail.layer setBorderWidth: 2.0];
             
             
             }
             */
        }
        [_cellCache setObject:cell forKey:key];
    }
    //Re-enable user interaction if it was disabled
    
    return cell;
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{

    //TODO: Read this 
    // http://stackoverflow.com/questions/2655630/how-can-you-add-a-uigesturerecognizer-to-a-uibarbuttonitem-as-in-the-common-undo
    // https://developer.apple.com/library/ios/#documentation/WindowsViews/Conceptual/ViewControllerCatalog/Chapters/Popovers.html#//apple_ref/doc/uid/TP40011313-CH5-SW1
    
    [super viewDidLoad];
    
	// Do any additional setup after loading the view, typically from a nib.
    
    //Configure the sort buttons based on preferences
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    UIBarButtonItem* spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];  
    NSMutableArray* toobarItems=[NSMutableArray arrayWithObject:spacer];

    NSInteger buttonCount;

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) buttonCount = 6;
    else buttonCount = 4;
    
    for(NSInteger i = 1; i<=buttonCount; ++i){
        //Because this preference is not used anywhere else, it is accessed directly.
        NSString* sortField =  [defaults objectForKey:[NSString stringWithFormat: @"itemListView_sortButton%i",i]];
        NSString* title;
        if(sortField != NULL){
            title = [ZPLocalization getLocalizationStringWithKey:sortField type:@"field"];
        }
        else if(i<5){
            if(i==1) sortField =  @"title";
            else if(i==2) sortField =  @"creator";
            else if(i==3) sortField =  @"date";
            else if(i==4) sortField =  @"dateModified";
            
            [defaults setObject:sortField forKey:[NSString stringWithFormat: @"itemListView_sortButton%i",i]];
            title = [ZPLocalization getLocalizationStringWithKey:sortField type:@"field"];

        }
        else{
            title = @"Tap and hold to set";
        }
        
        UIButton* button  = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(0,0, 101, 30);
        [button setImage:[UIImage imageNamed:@"barbutton_image_up_state.png"] forState:UIControlStateNormal];
        [button setImage:[UIImage imageNamed:@"barbutton_image_down_state.png"] forState:UIControlStateHighlighted];
        
        UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(0,0, 90, 30)];
        
        label.textAlignment = UITextAlignmentCenter;
        label.adjustsFontSizeToFitWidth = YES;
        label.text = title;
        label.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor whiteColor];
        label.center = button.center;
        label.font =  [UIFont fontWithName:@"Helvetica-Bold" size:12.0f];
        
        [button addSubview:label];
        
        [button addTarget:self action:@selector(sortButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        button.tag = i;
        
        UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(sortButtonLongPressed:)];
        [button addGestureRecognizer:longPressRecognizer]; 

        UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:button];
        barButton.tag=i;

        [toobarItems addObject:barButton];
        [toobarItems addObject:spacer];


    }
    [_toolBar setItems:toobarItems];
    [self configureView];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

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

#pragma mark - Actions

-(IBAction) sortButtonPressed:(id)sender{

    _tagForActiveSortButton = [(UIView*)sender tag];
    
    //Because this preference is not used anywhere else, it is accessed directly.
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* sortField =  [defaults objectForKey:[NSString stringWithFormat: @"itemListView_sortButton%i",[sender tag]]];
    if(sortField == NULL){
        [self sortButtonLongPressed:sender];
    }
        
    else{
        if([sortField isEqualToString: _sortField ]){
        _sortDescending = !_sortDescending;
        }
        else{
            _sortField = sortField;
            _sortDescending = FALSE;
        }
        
        [self configureView];
    }

}


-(void) sortButtonLongPressed:(UILongPressGestureRecognizer*)sender{
    
    if(sender.state == UIGestureRecognizerStateBegan ){
        _tagForActiveSortButton = [sender view].tag;
        
        UIBarButtonItem* button;
        for(button in _toolBar.items){
            if(button.tag == _tagForActiveSortButton) break;
        }
        
        ZPItemListViewController_sortHelper* tableViewController = [[ZPItemListViewController_sortHelper alloc] init];
        UITableView* tableView = [[UITableView alloc] init];
        
        tableViewController.tableView = tableView;
        tableView.delegate =tableViewController;
        tableView.dataSource = tableViewController;
        
        tableViewController.popover = [[UIPopoverController alloc] initWithContentViewController:tableViewController];
        tableViewController.targetButton = (UIButton*) button.customView;
        
        [tableViewController.popover presentPopoverFromBarButtonItem:button permittedArrowDirections: UIPopoverArrowDirectionAny animated:YES];
    }
}


-(void) clearSearch{
    _searchString = NULL;
    [_searchBar setText:@""];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sourceSearchBar{
    
    if(![[sourceSearchBar text] isEqualToString:_searchString]){
        _searchString = [sourceSearchBar text];
        [self configureView];
    }
    [sourceSearchBar resignFirstResponder ];
}

@end
