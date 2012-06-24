//
//  ZPPreviewController.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 23.6.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//


#import <QuickLook/QuickLook.h>

@interface ZPPreviewController : QLPreviewController <QLPreviewControllerDelegate>{
    UIView* _source;
    ZPAttachmentFileInteractionController* _attachmentInteractionController;
}
+(void) displayQuicklookWithAttachment:(ZPZoteroAttachment*)attachment sourceView:(UIView*)view;

@end

