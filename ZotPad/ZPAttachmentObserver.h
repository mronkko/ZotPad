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
-(void) notifyAttachmentDownloadFailed:(ZPZoteroAttachment*) attachment withError:(NSError*) error;
-(void) notifyAttachmentDownloadStarted:(ZPZoteroAttachment*) attachment;

-(void) notifyAttachmentDeleted:(ZPZoteroAttachment*) attachment fileAttributes:(NSDictionary*) fileAttributes;

-(void) notifyAttachmentUploadCompleted:(ZPZoteroAttachment*) attachment;
-(void) notifyAttachmentUploadFailed:(ZPZoteroAttachment*) attachment withError:(NSError*) error;
-(void) notifyAttachmentUploadStarted:(ZPZoteroAttachment*) attachment;
-(void) notifyAttachmentUploadCanceled:(ZPZoteroAttachment*) attachment;



@end
