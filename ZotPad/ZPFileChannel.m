//
//  ZPFileChannel.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
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
    
    [attachment logFileRevisions];

    UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;
    UIStoryboard *storyboard = root.storyboard;
    ZPUploadVersionConflictViewControllerViewController* viewController = [storyboard instantiateViewControllerWithIdentifier:@"VersionConflictView"];
    viewController.attachment = attachment;
    viewController.fileChannel = self;
    
    UIViewController* top = root;
    while(top.presentedViewController) top = top.presentedViewController;
    
    [top presentModalViewController:viewController animated:YES];
}


-(NSString*) requestDumpAsString:(ASIHTTPRequest*)request{

    NSMutableString* dump = [[NSMutableString alloc] initWithFormat:@"Request: \n\n%@ %@ HTTP/1.1\n",request.requestMethod,request.url];
    
    for(NSString* key in request.requestHeaders){
        [dump appendFormat:@"%@: %@\n",key,[request.requestHeaders objectForKey:key]];
    }
    
    if(request.postBody){
        [dump appendString:@"\n"];
        [dump appendString:[[NSString alloc] initWithData:request.postBody
                                                 encoding:NSUTF8StringEncoding]];
    }

    [dump appendFormat: @"\n\nResponse: \n\n%@\n",request.responseStatusMessage];

    for(NSString* key in request.responseHeaders){
        [dump appendFormat:@"%@: %@\n",key,[request.responseHeaders objectForKey:key]];
    }

    if(request.responseString){
        [dump appendString:@"\n"];
        [dump appendString:request.responseString];
    }
    return dump;
}




@end
