//
//  ZPFileChannel_DropBox.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DropboxSDK/DropboxSDK.h>
#import "ZPFileChannel.h"

extern const NSInteger ZPFILECHANNEL_DROPBOX_UPLOAD;
extern const NSInteger ZPFILECHANNEL_DROPBOX_DOWNLOAD;

@interface ZPFileChannel_Dropbox : ZPFileChannel <DBRestClientDelegate, DBSessionDelegate>{
    NSMutableDictionary* progressViewsByRequest;
    NSMutableDictionary* downloadCountsByRequest;
    NSMutableDictionary* remoteVersions;
}

+(void)linkDroboxIfNeeded;
-(NSObject*) keyForRequest:(NSObject*)request;

@end
