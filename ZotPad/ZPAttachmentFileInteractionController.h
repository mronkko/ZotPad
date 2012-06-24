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
}

-(void) setAttachment:(ZPZoteroAttachment*)attachment;
-(void) presentOptionsMenuFromBarButtonItem:(UIBarButtonItem*)button;

@end
