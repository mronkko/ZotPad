//
//  ZPDetailViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//


#import "ZPDetailedItemListViewController.h"
#import "ZPLibraryAndCollectionListViewController.h"
#import "ZPDataLayer.h"
#import <QuartzCore/QuartzCore.h>
#import "../DSActivityView/Sources/DSActivityView.h"

@interface ZPDetailedItemListViewController ()
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@end

@implementation ZPDetailedItemListViewController

@synthesize collectionKey = _collectionKey;
@synthesize libraryID =  _libraryID;
@synthesize searchString = _searchString;
@synthesize orderField = _orderField;
@synthesize sortDescending = _sortDescending;

@synthesize masterPopoverController = _masterPopoverController;

@synthesize searchBar;

static ZPDetailedItemListViewController* _instance = nil;

#pragma mark - Managing the detail item

-(id) init{
    self = [super init];
    return self;
}

+ (ZPDetailedItemListViewController*) instance{
    return _instance;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

/*
 
 Configures the view  
 */

- (void)configureView
{

    if([NSThread isMainThread]){
        // Update the user interface for the detail item.
        
        if (self.masterPopoverController != nil) {
            [self.masterPopoverController dismissPopoverAnimated:YES];
        }
        
        // Retrieve the item IDs if a library is selected. 
        
        if(_libraryID!=0){
            //TODO: Sort based on modified time by default so that the order will be the same that we will receive from the server.
            
            [self setItemKeysShownArray:
             [NSMutableArray arrayWithArray: [[ZPDataLayer instance] getItemKeysFromCacheForLibrary:self.libraryID collection:self.collectionKey
                                                                                                       searchString:[self.searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]orderField:self.orderField sortDescending:self.sortDescending]]
              itemKeysFromServerArray:[[ZPDataLayer instance] getItemKeysFromServerForLibrary:self.libraryID collection:self.collectionKey
                                                                                 searchString:[self.searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]orderField:self.orderField sortDescending:self.sortDescending]];
            
            [_tableView reloadData];
        }
    }
    else{
        [self performSelectorOnMainThread:@selector(configureView) withObject:NULL waitUntilDone:FALSE];
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

   
    //This array contains NSStrings and NSNulls. Nulls mean that there is no data available yet
    NSObject* keyObj = [_itemKeysShown objectAtIndex: indexPath.row];
    
    
    UITableViewCell* cell = [_cellCache objectForKey:keyObj];
    
    
    if(cell==nil){
        
        cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];

        
        if(keyObj != [NSNull null]){

            //If the cell contains an item, add publication details and thumbnail
            
            ZPZoteroItem* item=[[ZPDataLayer instance] getItemByKey:(NSString*)keyObj];

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
            //Get the authors label so that we can align publication details label with it
            UILabel *authorsLabel = (UILabel *)[cell viewWithTag:2];
            
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
        [_cellCache setObject:cell forKey:keyObj];
    }
    
    return cell;
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
   
    [super viewDidLoad];
    
	// Do any additional setup after loading the view, typically from a nib.

    _instance = self;
    

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

-(void) doOrderField:(NSString*)value{
    if([value isEqualToString: _orderField ]){
        _sortDescending = !_sortDescending;
    }
    else{
        _orderField = value;
        _sortDescending = FALSE;
    }
    
    [self configureView];
}

-(IBAction)doSortCreator:(id)sender{
    [self doOrderField:@"creator"];
}

-(IBAction)doSortDate:(id)sender{
    [self doOrderField:@"date"];
}

-(IBAction)doSortTitle:(id)sender{
    [self doOrderField:@"title"];
}

-(IBAction)doSortPublication:(id)sender{
    [self doOrderField:@"publicationTitle"];
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
