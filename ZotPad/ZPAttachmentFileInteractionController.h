//
//  ZPThumbnailButtonTarget.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 1/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroItem.h"
#import "ZPZoteroAttachment.h"
#import "ZPAttachmentObserver.h"

#import <Foundation/Foundation.h>

//For sending attachments with email
#import <MessageUI/MessageUI.h>

//For showing file thumbnails
#import <QuickLook/QuickLook.h>

@interface ZPAttachmentFileInteractionController: NSObject <UIActionSheetDelegate>{
//<QLPreviewControllerDataSource, QLPreviewControllerDelegate>{
    UIView* _source;
}

-(id) initWithAttachment:(ZPZoteroItem*)attachment sourceView:(UIView*)view;
-(void) presentOptionsMenuFromBarButtonItem:(UIBarButtonItem*)button;
-(void) displayQuicklook;

@end
