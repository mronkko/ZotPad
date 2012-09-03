//
//  ZPPreviewController.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 23.6.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//


#import <QuickLook/QuickLook.h>
#import "ZPPreviewSource.h"
#import "ZPAttachmentFileInteractionController.h"

@interface ZPPreviewController : QLPreviewController <QLPreviewControllerDelegate>{
    id <ZPPreviewSource> _source;
    ZPAttachmentFileInteractionController* _attachmentInteractionController;
}
+(void) displayQuicklookWithAttachment:(ZPZoteroAttachment*)attachment source:(id <ZPPreviewSource>)source;

@end

