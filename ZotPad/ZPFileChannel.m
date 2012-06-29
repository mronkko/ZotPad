//
//  ZPFileChannel.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPCore.h"

#import "ZPFileChannel.h"
#import "ZPZoteroAttachment.h"
#import "ZPServerConnection.h"
#import "ZPUploadVersionConflictViewControllerViewController.h"


@implementation ZPFileChannel

-(id) init{
    self = [super init];
    _requestsByAttachment = [[NSMutableDictionary alloc] init];
    return self;
}

-(int) fileChannelType{
    return 0;
}
-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    //Does nothing by default
}
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    //Does nothing by default
}
-(void) useProgressView:(UIProgressView*) progressView forDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    //Does nothing by default
}

-(void) startUploadingAttachment:(ZPZoteroAttachment*)attachment{
    //Does nothing by default
}

-(void) cancelUploadingAttachment:(ZPZoteroAttachment*)attachment{
    //Does nothing by default
}

-(void) useProgressView:(UIProgressView*) progressView forUploadingAttachment:(ZPZoteroAttachment*)attachment{
    //Does nothing by default
}

 
 
-(void) linkAttachment:(ZPZoteroAttachment*)attachment withRequest:(NSObject*)request{
    @synchronized(self){
        [_requestsByAttachment setObject:request forKey:attachment.key];
    }
}

-(id) requestWithAttachment:(ZPZoteroAttachment*)attachment{
    id ret;
    @synchronized(self){
        ret = [_requestsByAttachment objectForKey:attachment.key];
    }
    return ret;
}


-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment*)attachment{
    @synchronized(self){
        [_requestsByAttachment removeObjectForKey:attachment.key];
    }
}

-(void) presentConflictViewForAttachment:(ZPZoteroAttachment*) attachment{
    UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;
    UIStoryboard *storyboard = root.storyboard;
    ZPUploadVersionConflictViewControllerViewController* viewController = [storyboard instantiateViewControllerWithIdentifier:@"VersionConflictView"];
    viewController.attachment = attachment;
    viewController.fileChannel = self;
    if(root.presentedViewController){
        [root.presentedViewController presentModalViewController:viewController animated:YES];
    }
    else{
        [root presentModalViewController:viewController animated:YES];
    }
}





@end
