//
//  ZPThumbnailButtonTarget.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 1/2/12.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPZoteroItem.h"
#import "ZPZoteroAttachment.h"


#import <Foundation/Foundation.h>

//For sending attachments with email
#import <MessageUI/MessageUI.h>

//For showing file thumbnails
#import <QuickLook/QuickLook.h>

@interface ZPAttachmentFileInteractionController: NSObject <UIActionSheetDelegate, UIDocumentInteractionControllerDelegate, MFMailComposeViewControllerDelegate>{
}

-(void) setAttachment:(ZPZoteroAttachment*)attachment;
-(void) presentOptionsMenuFromBarButtonItem:(UIBarButtonItem*)button;

@end
