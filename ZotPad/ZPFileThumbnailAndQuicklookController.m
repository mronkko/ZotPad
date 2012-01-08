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

#import "ZPLogger.h"

@interface ZPFileThumbnailAndQuicklookController()

-(UIImage*) _renderThumbnailFromPDFFile:(NSString*)filename;
-(CGRect)_getDimensionsWithImage:(UIImage*) image; 
-(UIImage*) _getImage:(NSInteger) index;

@end


@implementation ZPFileThumbnailAndQuicklookController

-(id) initWithItem:(ZPZoteroItem*)item viewController:(UIViewController*) viewController maxHeight:(NSInteger)maxHeight maxWidth:(NSInteger)maxWidth{
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
    [_viewController presentModalViewController:quicklook animated:YES];

    //Mark these items as recently viewed
    for(ZPZoteroAttachment* attachment in [_item allExistingAttachments]){
        [[ZPDatabase instance] updateViewedTimestamp:attachment];
    }
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
            else break;
        }
    }

    return image;
}

//TODO: Consider recycling the uibutton and uiimageview objects

-(UIButton*) thumbnailAsUIButton{
    UIButton* button= [[UIButton alloc] init];

    ZPZoteroAttachment* attachment = [_item.attachments objectAtIndex:0];
    
    UIImage* image  = [self _getImage:0];
    [button setImage:image forState:UIControlStateNormal];

    if([attachment fileExists] && [attachment.attachmentType isEqualToString:@"application/pdf"]) button.frame=[self _getDimensionsWithImage:image];

    return button;
}

-(UIImageView*) thumbnailAsUIImageView:(NSInteger) index{

    
    ZPZoteroAttachment* attachment = [_item.attachments objectAtIndex:index];
    
    NSLog(@"Getting thumbnail for %@",attachment.fileSystemPath);
    UIImage* image  = [self _getImage:index];
    NSLog(@"Got thumbnail for %@",attachment.fileSystemPath);

    UIImageView* view = [[UIImageView alloc] initWithImage:image];

    if([attachment fileExists] && [attachment.attachmentType isEqualToString:@"application/pdf"]) view.frame=[self _getDimensionsWithImage:image];
    else view.frame = CGRectMake(0, 0, _maxWidth, _maxHeight);

    view.backgroundColor = [UIColor whiteColor];
    view.layer.borderWidth = 2.0f;

    return view;
}

//TODO: HIGH PRIORITY - Render the PDF pages in a background thread and display as they became available.

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
