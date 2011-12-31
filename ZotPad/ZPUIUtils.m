//
//  ZPUIUtils.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/29/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPUIUtils.h"

@implementation ZPUIUtils


+(UIImageView*)renderThumbnailFromPDFFile:(NSString*)filename maxHeight:(NSInteger)maxHeight maxWidth:(NSInteger)maxWidth{

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
    
    float scalingFactor = maxHeight/image.size.height;

    if(maxWidth/image.size.width<scalingFactor) scalingFactor = maxWidth/image.size.width;
        
    UIImageView* view = [[UIImageView alloc] initWithImage: image];
    [view setFrame:CGRectMake(0,0,image.size.width*scalingFactor,image.size.height*scalingFactor)];
    return view;
}

@end
