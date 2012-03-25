//
//  ZPFileChannel.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroAttachment.h"
@interface ZPFileChannel : NSObject {
    NSMutableDictionary *requestsByAttachment;
    NSMutableDictionary *attachmentsByRequest;
}

-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) useProgressView:(UIProgressView*) progressView forAttachment:(ZPZoteroAttachment*)attachment;
-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment*)attachment;

@end
