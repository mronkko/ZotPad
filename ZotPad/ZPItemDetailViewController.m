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

#define ATTACHMENT_VIEW_HEIGHT 600

#define ATTACHMENT_IMAGE_HEIGHT 580
#define ATTACHMENT_IMAGE_WIDTH 423

@interface ZPItemDetailViewController(){
    NSOperationQueue* _imageRenderQueue;
}
- (void) _reconfigureDetailTableView:(BOOL)animated;
- (void) _reconfigureCarousel;
- (NSString*) _textAtIndexPath:(NSIndexPath*)indexPath isTitle:(BOOL)isTitle;

- (BOOL) _useAbstractCell:(NSIndexPath*)indexPath;
-(void) _configurePreview:(UIView*) view withAttachment:(ZPZoteroAttachment*)attachment;
-(void) _configurePreviewLabel:(UIView*)view withAttachment:(ZPZoteroAttachment*)attachment;
-(void) _renderThumbnailFromPDFFile:(ZPZoteroAttachment*)attachment;
    
-(void) _reloadAttachmentInCarousel:(ZPZoteroItem*)attachment;
-(void) _reloadCarouselItemAtIndex:(NSInteger) index;

-(CGRect)_getDimensionsWithImage:(UIImage*) image; 

@end

@implementation ZPItemDetailViewController


@synthesize selectedItem = _currentItem;
@synthesize detailTableView = _detailTableView;
@synthesize carousel = _carousel;

#pragma mark - View lifecycle

static ZPItemDetailViewController* _instance;

+(ZPItemDetailViewController*) instance{
    return _instance;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _instance = self;
    
    [[ZPDataLayer instance] registerItemObserver:self];
    [[ZPDataLayer instance] registerAttachmentObserver:self];

    _detailTableView.scrollEnabled = FALSE;
    
    _imageRenderQueue = [[NSOperationQueue alloc] init];
    [_imageRenderQueue setMaxConcurrentOperationCount:3];

    _previewCache = [[NSCache alloc] init];
    [_previewCache setCountLimit:20];
    
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


}

- (void)viewWillAppear:(BOOL)animated
{
    //We need the dimensions of the view to be set before reconfiguring.
    [self configure];
    //Set self as a delegate for the navigation controller so that we know when the view is being dismissed by the navigation controller and know to pop the other navigation controller.
    [self.navigationController setDelegate:self];
    [super viewWillAppear:animated];

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


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    [_previewCache removeAllObjects];
}

-(void) configure{
    
    //TODO: This object should probably be recycled.
    
    _previewController = [[ZPFileThumbnailAndQuicklookController alloc] initWithItem:_currentItem viewController:self maxHeight:ATTACHMENT_IMAGE_HEIGHT maxWidth:ATTACHMENT_IMAGE_WIDTH];

    
    if([[ZPPreferences instance] online]){
        [_activityIndicator startAnimating];
        [[ZPDataLayer instance] updateItemDetailsFromServer:_currentItem];
    }
        

    
    [self _reconfigureDetailTableView:FALSE];
    [self _reconfigureCarousel];



    if(_currentItem.creatorSummary!=NULL && ! [_currentItem.creatorSummary isEqualToString:@""]){
        if(_currentItem.date!=0){
            self.navigationItem.title=[NSString stringWithFormat:@"%@ (%i) %@",_currentItem.creatorSummary,_currentItem.date,_currentItem.title];
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
        [_carousel performSelectorOnMainThread:@selector(reloadData) withObject:NULL waitUntilDone:NO];
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
- (void)viewWillDisappear:(BOOL)animated
{
    //Pop the item navigator away from the navigator.
    
    
    [[ZPDataLayer instance] removeItemObserver:self];
    
	[super viewWillDisappear:animated];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated{
    if(viewController != self){
        //Pop the other controller if something else than self is showing
        [[[ZPLibraryAndCollectionListViewController instance] navigationController] popViewControllerAnimated:YES];
        
        //Remove delegate because we no longer need to pop the other controller
        [navigationController setDelegate:NULL];
    }
}


-(void) _configurePreviewLabel:(UIView*)view withAttachment:(ZPZoteroAttachment*)attachment{
    
    //Add a label over the view
    NSString* extraInfo;
    
    
    if([attachment fileExists] && ![attachment.attachmentType isEqualToString:@"application/pdf"]){
        extraInfo = [@"Preview not supported for " stringByAppendingString:attachment.attachmentType];
    }
    else if(![attachment fileExists] ){
        if([[ZPPreferences instance] online]) extraInfo = [NSString stringWithFormat:@"Tap to download %i KB.",attachment.attachmentLength/1024];
        else  extraInfo = @"File has not been downloaded";
    }
    
    //Add information over the thumbnail
    
    
    UILabel* label = [[UILabel alloc] init];
    
    if(extraInfo!=NULL) label.text = [NSString stringWithFormat:@"%@ \n\n(%@)", attachment.attachmentTitle, extraInfo];
    else label.text = [NSString stringWithFormat:@"%@", attachment.attachmentTitle];
    
    label.textColor = [UIColor whiteColor];
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = UITextAlignmentCenter;
    label.lineBreakMode = UILineBreakModeWordWrap;
    label.numberOfLines = 5;
    label.frame=CGRectMake(50, 200, view.frame.size.width-100, view.frame.size.height-400);
    
    UIView* background = [[UIView alloc] init];
    background.frame=CGRectMake(40, 190, view.frame.size.width-80, view.frame.size.height-380);
    background.backgroundColor=[UIColor blackColor];
    background.alpha = 0.5;
    background.layer.cornerRadius = 8;
    
    [view addSubview:background];
    [view addSubview:label];
}

-(void) _configurePreview:(UIView*)view withAttachment:(ZPZoteroAttachment*)attachment{
    
    
    for(UIView* subview in view.subviews){
        [subview removeFromSuperview];
    }
    view.layer.borderWidth = 2.0f;
    view.backgroundColor = [UIColor whiteColor];
    
    UIImageView* imageView = NULL;
    if(attachment.fileExists && [attachment.attachmentType isEqualToString:@"application/pdf"]){

        UIImage* image = [_previewCache objectForKey:attachment.fileSystemPath];
        
        if(image == NULL){
            NSLog(@"Start rendering %@",attachment.fileSystemPath);
            [_previewCache setObject:[NSNull null] forKey:attachment.fileSystemPath];
            
            //Create an invocation
            NSInvocationOperation* operation  = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_renderThumbnailFromPDFFile:) object:attachment]; 
            //Create operation and queue it for background retrieval
            [_imageRenderQueue addOperation:operation];
            NSLog(@"Added file %@ to preview render queue. Operations in queue now %i",attachment.attachmentTitle,[_imageRenderQueue operationCount]);
        }
        else if(image != [NSNull null]){
            NSLog(@"Got an image from cache %@",attachment.fileSystemPath);
            imageView = [[UIImageView alloc] initWithImage:image];
            view.layer.frame = [self _getDimensionsWithImage:image];
            imageView.layer.frame = [self _getDimensionsWithImage:image];
        }
        else NSLog(@"Image is being rendered %@",attachment.fileSystemPath);
    }
    
    if(imageView == NULL){
        imageView = [[UIImageView alloc] initWithImage:[_previewController getFiletypeImage:attachment]];   
    }

    [view addSubview:imageView];
    imageView.center = view.center;
    
    //Configure label
    [self _configurePreviewLabel:view withAttachment:attachment];
    
}


-(CGRect)_getDimensionsWithImage:(UIImage*) image{    
    
    float scalingFactor = ATTACHMENT_IMAGE_HEIGHT/image.size.height;
    
    if(ATTACHMENT_IMAGE_HEIGHT/image.size.width<scalingFactor) scalingFactor = ATTACHMENT_IMAGE_WIDTH/image.size.width;
    
    return CGRectMake(0,0,image.size.width*scalingFactor,image.size.height*scalingFactor);
    
}


-(void) _renderThumbnailFromPDFFile:(ZPZoteroAttachment*)attachment{
    
    //
    // Renders a first page of a PDF as an image
    //
    // Source: http://stackoverflow.com/questions/5658993/creating-pdf-thumbnail-in-iphone
    //
    NSString* filename = attachment.fileSystemPath;
    
    NSLog(@"Start rendering pdf %@",filename);
    
    NSURL *pdfUrl = [NSURL fileURLWithPath:filename];
    CGPDFDocumentRef document = CGPDFDocumentCreateWithURL((__bridge_retained CFURLRef)pdfUrl);
    
    
    CGPDFPageRef pageRef = CGPDFDocumentGetPage(document, 1);
    CGRect pageRect = CGPDFPageGetBoxRect(pageRef, kCGPDFCropBox);
    
    UIGraphicsBeginImageContext(pageRect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, CGRectGetMinX(pageRect),CGRectGetMaxY(pageRect));
    CGContextScaleCTM(context, 1, -1);  
    CGContextTranslateCTM(context, -(pageRect.origin.x), -(pageRect.origin.y));
    CGContextDrawPDFPage(context, pageRef);
    
    UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    NSLog(@"Done rendering pdf %@",filename);
    
    [_previewCache setObject:image forKey:filename];

    [self performSelectorOnMainThread:@selector(_reloadAttachmentInCarousel:) withObject:attachment waitUntilDone:NO];
    
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
    
    // Navigator
    else{
        // Get the key for the selected item 
        NSArray* itemArray =[(ZPSimpleItemListViewController*) aTableView.dataSource itemKeysShown];
        if(indexPath.row<[itemArray count]){                    
            NSString* currentItemKey = [itemArray objectAtIndex: indexPath.row]; 
            
            if(currentItemKey != [NSNull null]){
                _currentItem = [ZPZoteroItem retrieveOrInitializeWithKey:currentItemKey];
                [self configure];
            }
            
        }
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
        [self performSelectorOnMainThread:@selector(_reconfigureDetailTableView:) withObject:[NSNumber numberWithBool:TRUE] waitUntilDone:NO];

        [_activityIndicator stopAnimating];

    }
}

-(void) notifyAttachmentDownloadCompleted:(ZPZoteroAttachment*) attachment{
    [self _reloadAttachmentInCarousel:attachment];
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

- (UIView *)carousel:(iCarousel *)carousel viewForItemAtIndex:(NSUInteger)index reusingView:(UIView*)view
{
    
    ZPZoteroAttachment* attachment = [_currentItem.attachments objectAtIndex:index];
    //TOOD: Recycle views    
    view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ATTACHMENT_IMAGE_WIDTH, ATTACHMENT_IMAGE_HEIGHT)];
    [self _configurePreview:view withAttachment:attachment];
        
    return view;
}

//This is implemented because it is a mandatory protocol method
- (UIView *)carousel:(iCarousel *)carousel placeholderViewAtIndex:(NSUInteger)index reusingView:(UIView *)view{
    if(view==NULL) return view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ATTACHMENT_IMAGE_WIDTH, ATTACHMENT_IMAGE_HEIGHT)];
    return view;
}

#pragma mark -

@end
