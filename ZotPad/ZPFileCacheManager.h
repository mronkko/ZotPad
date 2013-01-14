//
//  ZPFileCacheManager.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 1/5/13.
//
//

#import <Foundation/Foundation.h>
#import "ZPCacheStatusToolbarController.h"
#import "ZPCore.h"

@interface ZPFileCacheManager : NSObject

//Attachments
+(void) purgeAllAttachmentFilesFromCache;
+(void) setStatusView:(ZPCacheStatusToolbarController*)statusView;
+(BOOL) isCacheLimitReached;
+(void) deleteOriginalFileForAttachment:(ZPZoteroAttachment*)attachment reason:(NSString*) reason;
+(void) deleteModifiedFileForAttachment:(ZPZoteroAttachment*)attachment reason:(NSString*) reason;
+(void) storeOriginalFileForAttachment:(ZPZoteroAttachment*)attachment fromPath:(NSString*)path;
+(void) storeModifiedFileForAttachment:(ZPZoteroAttachment*)attachment fromPath:(NSString*)path;

@end
