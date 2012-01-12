//
//  ZPDetailViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPDetailViewController.h"
#import "ZPDataLayer.h"
#import <QuartzCore/QuartzCore.h>
#import "../DSActivityView/Sources/DSActivityView.h"

@interface ZPDetailViewController ()
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@end

@implementation ZPDetailViewController

@synthesize collectionID = _collectionKey;
@synthesize libraryID =  _libraryID;
@synthesize searchString = _searchString;
@synthesize sortField = _sortField;
@synthesize sortDescending = _sortDescending;

@synthesize masterPopoverController = _masterPopoverController;

@synthesize itemTableView;
@synthesize searchBar;

@synthesize itemKeysShown = _itemKeysShown;


static ZPDetailViewController* _instance = nil;

#pragma mark - Managing the detail item

-(id) init{
    self = [super init];
    _cellCache = [[NSCache alloc] init];
    
    return self;
}

+ (ZPDetailViewController*) instance{
    return _instance;
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
        _itemKeysShown = [[ZPDataLayer instance] getItemKeysForView: self];
        if(_itemKeysShown == NULL){
            [self makeBusy];
        }
        else{
            [self.itemTableView reloadData];
        }     
    }
}

//If we are not already displaying an activity view, do so now
/*
- (void)makeBusy{
    if(_activityView==NULL){
        if([NSThread isMainThread]){
        [self.itemTableView setUserInteractionEnabled:FALSE];
        _activityView = [DSBezelActivityView newActivityViewForView:self.itemTableView];
        }
        else{
            [self performSelectorOnMainThread:@selector(notifyDataAvailable) withObject:nil waitUntilDone:NO];
        }   
    }
}



- (void)notifyDataAvailable{
    
    if([NSThread isMainThread]){
        [self.itemTableView reloadData];
        [DSBezelActivityView removeViewAnimated:YES];
        [self.itemTableView setUserInteractionEnabled:TRUE];
        _activityView = NULL;
    }
    else{
        [self performSelectorOnMainThread:@selector(notifyDataAvailable) withObject:nil waitUntilDone:NO];
    }
    
}

- (void)notifyItemAvailable:(NSString*) key{
    
    
    NSEnumerator *e = [[self.itemTableView indexPathsForVisibleRows] objectEnumerator];
    
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
    [self.itemTableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];

}

*/

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

   
    
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
        
        
        ZPZoteroItem* item=NULL;
        if(![key isEqualToString:@""]) item = [ZPZoteroItem retrieveOrInitializeWithKey:key];
        
        if(item==NULL){
            cell = [tableView dequeueReusableCellWithIdentifier:@"LoadingCell"];        
        }
        else{

            cell = [tableView dequeueReusableCellWithIdentifier:@"ZoteroItemCell"];
            
            UILabel *titleLabel = (UILabel *)[cell viewWithTag:1];
            titleLabel.text = item.title;
            
            UILabel *authorsLabel = (UILabel *)[cell viewWithTag:2];
            
            //Show different things depending on what data we have
            if(item.creatorSummary!=NULL){
                if(item.year != 0){
                    authorsLabel.text = [NSString stringWithFormat:@"%@ (%i)",item.creatorSummary,item.year];
                }
                else{
                    authorsLabel.text = [NSString stringWithFormat:@"%@ (No date)",item.creatorSummary];
                }
            }    
            else if(item.year != 0){
                authorsLabel.text = [NSString stringWithFormat:@"No author (%i)",item.year];
            }

            //Publication as a formatted label

            NSString* publishedIn = item.publishedIn;
            
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

    
    [super viewDidLoad];
    
    // Store this instance as static variable so that we can access it through the class later
    if(_instance == NULL){
        _instance = self;
    }

	// Do any additional setup after loading the view, typically from a nib.
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
    barButtonItem.title = NSLocalizedString(@"Master", @"Master");
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

-(void) doSortField:(NSString*)value{
    if([value isEqualToString: _sortField ]){
        _sortDescending = !_sortDescending;
    }
    else{
        _sortField = value;
        _sortDescending = FALSE;
    }
    
    [self configureView];
}

-(IBAction)doSortCreator:(id)sender{
    [self doSortField:@"creator"];
}

-(IBAction)doSortDate:(id)sender{
    [self doSortField:@"date"];
}

-(IBAction)doSortTitle:(id)sender{
    [self doSortField:@"title"];
}

-(IBAction)doSortPublication:(id)sender{
    [self doSortField:@"publicationTitle"];
}

-(void) clearSearch{
    _searchString = NULL;
    [searchBar setText:@""];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sourceSearchBar{
    
    if(![[sourceSearchBar text] isEqualToString:_searchString]){
        _searchString = [sourceSearchBar text];
        [self configureView];
    }
    [sourceSearchBar resignFirstResponder ];
}

@end
