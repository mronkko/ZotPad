//
//  ZPFileChannel.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPFileChannel.h"
#import "ZPZoteroAttachment.h"
#import "ZPServerConnection.h"

@implementation ZPFileChannel

-(id) init{
    self = [super init];
    requestsByAttachment = [[NSMutableDictionary alloc] init];
    attachmentsByRequest = [[NSMutableDictionary alloc] init];
    return self;
}

-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    //By default just call the finish method
    [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:NULL usingFileChannel:self];
}
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    //Does nothing by default
}
-(void) useProgressView:(UIProgressView*) progressView forAttachment:(ZPZoteroAttachment*)attachment{
    //Does nothing by default
}
-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment*)attachment{
    @synchronized(self){
        NSObject* request = [requestsByAttachment objectForKey:attachment];
        [requestsByAttachment removeObjectForKey:attachment];
        [attachmentsByRequest removeObjectForKey:request];
    }
}


@end
