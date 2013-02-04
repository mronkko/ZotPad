//
//  ZPItemDataUploadManager.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 1/5/13.
//
//

#import <Foundation/Foundation.h>
#import "ZPCacheStatusToolbarController.h"

@interface ZPItemDataUploadManager : NSObject

+(void) setStatusView:(ZPCacheStatusToolbarController*)statusView;
+(void) uploadMetadata;

//Notifications
+(void)notifyUserInterfaceAvailable:(NSNotification*)notification;

@end
