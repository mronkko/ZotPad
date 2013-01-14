//
//  ZPFileUploadManager.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 1/5/13.
//
//

#import <Foundation/Foundation.h>
#import "ZPCacheStatusToolbarController.h"
#import "ZPCore.h"

@interface ZPFileUploadManager : NSObject

+(void) addAttachmentToUploadQueue:(ZPZoteroAttachment*) attachment withNewFile:(NSURL*)urlToFile;
+(void) setStatusView:(ZPCacheStatusToolbarController*)statusView;
+(void) useProgressView:(UIProgressView*) progressView forUploadingAttachment:(ZPZoteroAttachment*)attachment;


// Callbacks

+(void) finishedUploadingAttachment:(ZPZoteroAttachment*)attachment withVersionIdentifier:(NSString*)identifier;
+(void) failedUploadingAttachment:(ZPZoteroAttachment*)attachment withError:(NSError*) error toURL:(NSString*)url;
+(void) canceledUploadingAttachment:(ZPZoteroAttachment*)attachment;

// Notifications

+(void)notifyUserInterfaceAvailable:(NSNotification*)notification;

@end
