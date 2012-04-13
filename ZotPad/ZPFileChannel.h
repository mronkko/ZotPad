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
    NSMutableDictionary* _attachmentsByRequest;
    
    //Some file channels require username and password, so these are stored in this superclass
    NSString* _username;
    NSString* _password;
}

-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) useProgressView:(UIProgressView*) progressView forAttachment:(ZPZoteroAttachment*)attachment;

-(NSString*) username;
-(NSString*) password;

-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment*)attachment;
-(void) linkAttachment:(ZPZoteroAttachment*)attachment withRequest:(NSObject*)request;
-(NSObject*) keyForRequest:(NSObject*)request;
-(id) requestWithAttachment:(ZPZoteroAttachment*)attachment;
-(ZPZoteroAttachment*) attachmentWithRequest:(NSObject*)request;

@end
