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
    NSMutableDictionary* _requestsByAttachment;
}

-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) useProgressView:(UIProgressView*) progressView forDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(int) fileChannelType;


-(void) startUploadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) cancelUploadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) useProgressView:(UIProgressView*) progressView forUploadingAttachment:(ZPZoteroAttachment*)attachment;

//Helper methods

-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment*)attachment;
-(void) linkAttachment:(ZPZoteroAttachment*)attachment withRequest:(NSObject*)request;
-(id) requestWithAttachment:(ZPZoteroAttachment*)attachment;

-(void) presentConflictViewForAttachment:(ZPZoteroAttachment*) attachment;



@end
