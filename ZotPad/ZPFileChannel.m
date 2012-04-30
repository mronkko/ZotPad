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
    _requestsByAttachment = [[NSMutableDictionary alloc] init];
    _attachmentsByRequest = [[NSMutableDictionary alloc] init];
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
-(void) linkAttachment:(ZPZoteroAttachment*)attachment withRequest:(NSObject*)request{
    @synchronized(self){
        [_requestsByAttachment setObject:request forKey:attachment.key];
        [_attachmentsByRequest setObject:attachment forKey:[self keyForRequest:request]];
    }
}

-(NSString*) username{
    return _username;
}
-(NSString*) password{
    return _password;
}
-(void) setUsername:(NSString*)username andPassword:(NSString*)password{
    _username = username;
    _password = password;
}

-(NSObject*) keyForRequest:(NSObject*)request{
    return [NSNumber numberWithInt: request];
}
-(id) requestWithAttachment:(ZPZoteroAttachment*)attachment{
    id ret;
    @synchronized(self){
        ret = [_requestsByAttachment objectForKey:attachment.key];
    }
    return ret;
}
-(ZPZoteroAttachment*) attachmentWithRequest:(NSObject*)request{
    id ret;
    @synchronized(self){
        ret = [_attachmentsByRequest objectForKey:[self keyForRequest:request]];
    }
    return ret;

}

-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment*)attachment{
    @synchronized(self){
        NSObject* request = [self requestWithAttachment:attachment];
        [_requestsByAttachment removeObjectForKey:attachment.key];
        [_attachmentsByRequest removeObjectForKey:[self keyForRequest:request]];
    }
}


@end
