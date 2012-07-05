//
//  ZPFileChannel.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroAttachment.h"
#import "ASIHTTPRequest.h"



@interface ZPFileChannel : NSObject {
    NSMutableDictionary* _requestsByAttachment;
}

-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) useProgressView:(UIProgressView*) progressView forDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(int) fileChannelType;


-(void) startUploadingAttachment:(ZPZoteroAttachment*)attachment overWriteConflictingServerVersion:(BOOL)overwriteConflicting;
-(void) cancelUploadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) useProgressView:(UIProgressView*) progressView forUploadingAttachment:(ZPZoteroAttachment*)attachment;

//Helper methods

-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment*)attachment;
-(void) linkAttachment:(ZPZoteroAttachment*)attachment withRequest:(NSObject*)request;
-(id) requestWithAttachment:(ZPZoteroAttachment*)attachment;

-(void) presentConflictViewForAttachment:(ZPZoteroAttachment*) attachment;

/*
 Returns the content of a request and response as string. Useful for logging.
 */
-(NSString*) requestDumpAsString:(ASIHTTPRequest*)request;



@end
