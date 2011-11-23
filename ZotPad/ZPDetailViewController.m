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

@interface ZPDetailViewController ()
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@end

@implementation ZPDetailViewController

@synthesize collectionID = _collectionID;
@synthesize libraryID =  _libraryID;
@synthesize searchString = _searchString;
@synthesize sortField = _sortField;
@synthesize sortIsDescending = _sortIsDescending;

@synthesize masterPopoverController = _masterPopoverController;

@synthesize itemTableView;

#pragma mark - Managing the detail item

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [_itemIDsShown count];
}



- (void)configureView
{
    // Update the user interface for the detail item.
    
    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }
    
    // Retrieve the item IDs
    
    //TODO: Make this run asynchornously. See http://developer.apple.com/library/ios/#documentation/General/Conceptual/ConcurrencyProgrammingGuide/OperationQueues/OperationQueues.html
    self->_itemIDsShown = [[ZPDataLayer instance] getItemIDsForView: self];
    
    [self.itemTableView reloadData];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

   
    
    NSInteger itemID = [[_itemIDsShown objectAtIndex: indexPath.row]integerValue];

    //It is possible that we do not yet have data for the full view. Sleep until we have it
    //More data is retrieved in the background
    
    while(itemID==0){
        [NSThread sleepForTimeInterval:.5];
        itemID = [[_itemIDsShown objectAtIndex: indexPath.row]integerValue];
    }
    
    //TODO: Implement purging of the cache
    if(self->_cellCache==nil){
        self->_cellCache = [NSMutableDictionary dictionary];
    }
    
    
    
	UITableViewCell* cell = [self->_cellCache objectForKey:[NSNumber numberWithInteger:itemID]];
    
    if(cell==nil){
        
        cell = [tableView dequeueReusableCellWithIdentifier:@"ZoteroItemCell"];
        
        NSDictionary* itemFieldValues = [[ZPDataLayer instance] getFieldsForItem: itemID];
        
        UILabel *titleLabel = (UILabel *)[cell viewWithTag:1];
        titleLabel.text = [itemFieldValues objectForKey:@"title"];
        
        UILabel *authorsLabel = (UILabel *)[cell viewWithTag:2];
        authorsLabel.text = [[[ZPDataLayer instance] getCreatorsForItem: itemID]componentsJoinedByString: @"; "];
        
        UILabel *publicationLabel = (UILabel *)[cell viewWithTag:3];
        
        
        publicationLabel.text = [NSString stringWithFormat:@"%@, vol %@, iss %@ (%@)",[itemFieldValues objectForKey:@"publicationTitle"],[itemFieldValues objectForKey:@"volume"],[itemFieldValues objectForKey:@"issue"],[itemFieldValues objectForKey:@"date"]];
        
        //Check if the item has attachments and render a thumbnail from the first attachment PDF
        
        NSArray* attachmentFilePaths = [[ZPDataLayer instance] getAttachmentFilePathsForItem: itemID];
        
        if([attachmentFilePaths count] > 0 ){
            UIImageView* articleThumbnail = (UIImageView *) [cell viewWithTag:4];
            
            NSLog([attachmentFilePaths objectAtIndex:0]);
            
            NSURL *pdfUrl = [NSURL fileURLWithPath:[attachmentFilePaths objectAtIndex:0]];
            CGPDFDocumentRef document = CGPDFDocumentCreateWithURL((__bridge_retained CFURLRef)pdfUrl);
            
            /*
             
             Renders a first page of a PDF as an image
             
             Source: http://stackoverflow.com/questions/5658993/creating-pdf-thumbnail-in-iphone
             
             
             
             */
            
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
        
       [self->_cellCache setObject:cell forKey:[NSNumber numberWithInteger:itemID]];
    }
    return cell;
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{

    
    [super viewDidLoad];
    
    //Set library to my library if it is not defined
    
    if(self->_libraryID == 0){
        self->_libraryID = 1; 
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

@end
