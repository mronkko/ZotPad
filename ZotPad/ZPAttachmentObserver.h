//
//  ZPAttachmentObaserver.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/29/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroAttachment.h"

@protocol ZPAttachmentObserver <NSObject>

-(void) notifyAttachmentDownloadCompleted:(ZPZoteroAttachment*) attachment;
-(void) notifyAttachmentDownloadStarted:(ZPZoteroAttachment*) attachment;



@end
