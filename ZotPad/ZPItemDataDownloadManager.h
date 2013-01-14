//
//  ZPCache.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPCacheStatusToolbarController.h"


@interface ZPItemDataDownloadManager : NSObject

+(void) setStatusView:(ZPCacheStatusToolbarController*)statusView;

// Notifications
+(void) notifyActiveItemChanged:(NSNotification *) notification;
+(void) notifyActiveCollectionChanged:(NSNotification *) notification;
+(void) notifyActiveLibraryChanged:(NSNotification *) notification;
+(void) notifyAuthenticationSuccesful:(NSNotification*) notification;
+(void) notifyUserInterfaceAvailable:(NSNotification*)notification;

//Call backs
+(void) processNewItemsFromServer:(NSArray*)items forLibraryID:(NSInteger)libraryID;
+(void) processNewLibrariesFromServer:(NSArray*)items;
+(void) processNewCollectionsFromServer:(NSArray*)items forLibraryID:(NSInteger)libraryID;
+(void) processNewItemKeyListFromServer:(NSArray*)items forLibraryID:(NSInteger) libraryID;
+(void) processNewTopLevelItemKeyListFromServer:(NSArray*)items userInfo:(NSDictionary*)parameters;
+(void) processNewTimeStampForLibrary:(NSInteger)libraryID collection:(NSString*)key timestampValue:(NSString*)value;

@end
