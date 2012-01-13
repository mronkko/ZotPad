//
//  ZPThumbnailButtonTarget.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 1/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ZPFileThumbnailAndQuicklookController.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroAttachment.h"
#import "ZPDatabase.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import "ZPItemDetailViewController.h"

#import "ZPLogger.h"

@interface ZPFileThumbnailAndQuicklookController()
    

-(UIImage*) _renderThumbnailFromPDFFile:(NSString*)filename;
-(CGRect)_getDimensionsWithImage:(UIImage*) image; 
-(UIImage*) _getImage:(NSInteger) index;
-(void) _configureButton:(UIButton*) button;
-(void) _configurePreview:(UIView*) view withAttachment:(ZPZoteroAttachment*)attachment;
-(void) _configurePreviewLabel:(UIView*)view withAttachment:(ZPZoteroAttachment*)attachment;

@end



@implementation ZPFileThumbnailAndQuicklookController

static NSOperationQueue* _buttonRenderQueue;

-(id) initWithItem:(ZPZoteroItem*)item viewController:(UIViewController*) viewController maxHeight:(NSInteger)maxHeight maxWidth:(NSInteger)maxWidth{
    
    if(_buttonRenderQueue == NULL){
        _buttonRenderQueue = [[NSOperationQueue alloc] init];
        [_buttonRenderQueue setMaxConcurrentOperationCount:1];
    }
    
    self = [super init];
    _item= item;
    _viewController=viewController;
    _maxWidth=maxWidth;
    _maxHeight=maxHeight;
    
    return self;
}

-(void) buttonTapped{
    [self openInQuickLookWithAttachment:[_item firstExistingAttachment]];
}

#pragma mark QuickLook delegate methods

- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller 
{
    return [[_item allExistingAttachments] count];
}


- (id <QLPreviewItem>) previewController: (QLPreviewController *) controller previewItemAtIndex: (NSInteger) index{
    NSArray* allExisting = [_item allExistingAttachments];
    ZPZoteroAttachment* currentAttachment = [allExisting objectAtIndex:index];
    NSString* path = [currentAttachment fileSystemPath];
    return [NSURL fileURLWithPath:path];
}


-(void) openInQuickLookWithAttachment:(ZPZoteroAttachment*) attachment{

    QLPreviewController *quicklook = [[QLPreviewController alloc] init];
    [quicklook setDataSource:self];
    [quicklook setCurrentPreviewItemIndex:[[_item allExistingAttachments] indexOfObject:attachment]];
    
    UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;       
    [root presentModalViewController:quicklook animated:YES];

    //Mark these items as recently viewed
    for(ZPZoteroAttachment* attachment in [_item allExistingAttachments]){
        [[ZPDatabase instance] updateViewedTimestamp:attachment];
    }
    //resignFirstResponder
}

-(CGRect)_getDimensionsWithImage:(UIImage*) image{    
    
    float scalingFactor = _maxHeight/image.size.height;
    
    if(_maxWidth/image.size.width<scalingFactor) scalingFactor = _maxWidth/image.size.width;
    
    return CGRectMake(0,0,image.size.width*scalingFactor,image.size.height*scalingFactor);

}

-(UIImage*) _getImage:(NSInteger)index{

    ZPZoteroAttachment* attachment = [_item.attachments objectAtIndex:index];
                                    
    UIImage* image;
    
    if([attachment fileExists] && [attachment.attachmentType isEqualToString:@"application/pdf"]){
        image = [self _renderThumbnailFromPDFFile:[attachment fileSystemPath]];
    }
    else{
        // Source: http://stackoverflow.com/questions/5876895/using-built-in-icons-for-mime-type-or-uti-type-in-ios
        
        //Need to initialize this way or the doc controller doesn't work
        NSURL*fooUrl = [NSURL URLWithString:@"file://foot.dat"];
        UIDocumentInteractionController* docController = [UIDocumentInteractionController interactionControllerWithURL:fooUrl];
        
        //Need to convert from mime type to a UTI to be able to get icons for the document
        CFStringRef mime = (__bridge CFStringRef) attachment.attachmentType;
        NSString *uti = (__bridge NSString*) UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType,mime, NULL);
        
        //Tell the doc controller what UTI type we want
        docController.UTI = uti;

        //Get the largest image that can fit

        for(UIImage* icon in docController.icons) {
            if(icon.size.width<_maxWidth && icon.size.height<_maxHeight) image=icon;
            else{
                if(image==NULL) image=icon;
                break;   
            }
        }
    }

    return image;
}

//TODO: Consider recycling the uibutton and uiimageview objects

-(void) configureButton:(UIButton*) button{
    
    NSOperation* operation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_configureButton:) object:button];
    [_buttonRenderQueue addOperation:operation];
}

-(void) _configureButton:(UIButton*) button{

    UIImage* image;
    if([button superview] != nil) image  = [self _getImage:0];
    if([button superview] != nil){
        [button setImage:image forState:UIControlStateNormal];
        button.frame=[self _getDimensionsWithImage:image];
        [button setNeedsDisplay];
    }
    
}

-(void) _configurePreviewLabel:(UIView*)view withAttachment:(ZPZoteroAttachment*)attachment{

    //Add a label over the view
    NSString* extraInfo;
    
    
    if([attachment fileExists] && ![attachment.attachmentType isEqualToString:@"application/pdf"]){
        extraInfo = [@"Preview not supported for " stringByAppendingString:attachment.attachmentType];
    }
    else if(![attachment fileExists] ){
        extraInfo = [NSString stringWithFormat:@"Tap to download KB %i",attachment.attachmentLength/1024];
    }

    //Add information over the thumbnail


    UILabel* label = [[UILabel alloc] init];
    
    if(extraInfo!=NULL) label.text = [NSString stringWithFormat:@"%@ (%@)", attachment.attachmentTitle, extraInfo];
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

-(void) configurePreview:(UIView*)view withAttachment:(ZPZoteroAttachment*)attachment{
    
    for(UIView* subview in view.subviews){
        [subview removeFromSuperview];
    }

    [self _configurePreviewLabel:view withAttachment:attachment];
    view.layer.borderWidth = 2.0f;
    view.backgroundColor = [UIColor whiteColor];
    
    
    //Render an image 
    
    //Create an invocation
    SEL selector = @selector(_configurePreview:withAttachment:);
    NSMethodSignature* signature = [[self class] instanceMethodSignatureForSelector:selector];
    NSInvocation* invocation  = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:self];
    [invocation setSelector:selector];
    
    //Set arguments
    [invocation setArgument:&view atIndex:2];
    [invocation setArgument:&attachment atIndex:3];
    
    //Create operation and queue it for background retrieval
    NSOperation* operation = [[NSInvocationOperation alloc] initWithInvocation:invocation];
    [_buttonRenderQueue addOperation:operation];
}

-(void) _configurePreview:(UIView*)view withAttachment:(ZPZoteroAttachment*)attachment{

    //Render images
    
    UIImage* image;
    NSInteger index = [_item.attachments indexOfObject:attachment];
    if([view superview] != nil && index!=NSNotFound) image  = [self _getImage:index];
    if([view superview] != nil){
        
        UIView* subview;
        NSArray* subviews=[NSArray arrayWithArray:view.subviews];
        for(subview in subviews){
            [subview removeFromSuperview];
        }

        UIImageView* imageView = [[UIImageView alloc] initWithImage:image];

        if([attachment fileExists] && [attachment.attachmentType isEqualToString:@"application/pdf"]){
            view.layer.frame = [self _getDimensionsWithImage:image];
            imageView.layer.frame = [self _getDimensionsWithImage:image];
            [view setNeedsLayout];
        }
        
        [view addSubview:imageView];
        //Add the subviews back
        for(subview in subviews){
            [view addSubview:subview];
        }
        [view setNeedsDisplay];
        [[(ZPItemDetailViewController*) _viewController carousel] reloadItemAtIndex:[_item.attachments indexOfObject:attachment] animated:YES];

    }
}


-(UIImage*) _renderThumbnailFromPDFFile:(NSString*)filename{
    
    //
    // Renders a first page of a PDF as an image
    //
    // Source: http://stackoverflow.com/questions/5658993/creating-pdf-thumbnail-in-iphone
    //
    
    NSURL *pdfUrl = [NSURL fileURLWithPath:filename];
    CGPDFDocumentRef document = CGPDFDocumentCreateWithURL((__bridge_retained CFURLRef)pdfUrl);
    
    
    CGPDFPageRef pageRef = CGPDFDocumentGetPage(document, 1);
    CGRect pageRect = CGPDFPageGetBoxRect(pageRef, kCGPDFCropBox);
    
    NSLog(@"Rendering pdf, width = %f, height = %f",pageRect.size.width,pageRect.size.height);
    UIGraphicsBeginImageContext(pageRect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, CGRectGetMinX(pageRect),CGRectGetMaxY(pageRect));
    CGContextScaleCTM(context, 1, -1);  
    CGContextTranslateCTM(context, -(pageRect.origin.x), -(pageRect.origin.y));
    CGContextDrawPDFPage(context, pageRef);
    
    UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
    
}


@end
