//
//  ZPFileDownloadManager.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 1/5/13.
//
//

#import <Foundation/Foundation.h>
#import "ZPCacheStatusToolbarController.h"
#import "ZPFileChannel.h"
#import "ZPCore.h"

@interface ZPFileDownloadManager : NSObject

+(void) addAttachmentToDowloadQueue:(ZPZoteroAttachment *)attachment;
+(void) setStatusView:(ZPCacheStatusToolbarController*)statusView;


// Asynchronous downloading of files

+(BOOL) checkIfCanBeDownloadedAndStartDownloadingAttachment:(ZPZoteroAttachment*)attachment;
+(void) finishedDownloadingAttachment:(ZPZoteroAttachment*)attachment toFileAtPath:(NSString*) tempFile withVersionIdentifier:(NSString*) identifier;
+(void) failedDownloadingAttachment:(ZPZoteroAttachment*)attachment withError:(NSError*) error fromURL:(NSString*)url;
+(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment;
+(void) useProgressView:(UIProgressView*) progressView forDownloadingAttachment:(ZPZoteroAttachment*)attachment;
+(BOOL) isAttachmentDownloading:(ZPZoteroAttachment*)attachment;


// Notifications

+(void) notifyActiveItemChanged:(NSNotification *) notification;
+(void) notifyActiveCollectionChanged:(NSNotification *) notification;
+(void) notifyActiveLibraryChanged:(NSNotification *) notification;
+(void) notifyItemsAvailable:(NSNotification *) notification;
+(void) notifyUserInterfaceAvailable:(NSNotification*)notification;



@end
