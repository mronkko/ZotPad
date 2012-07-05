//
//  ZPFileChannel_WebDAV.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPFileChannel.h"


extern NSInteger const ZPFILECHANNEL_WEBDAV_DOWNLOAD;
extern NSInteger const ZPFILECHANNEL_WEBDAV_UPLOAD_FILE;
extern NSInteger const ZPFILECHANNEL_WEBDAV_UPLOAD_UPDATE_LASTSYNC;
extern NSInteger const ZPFILECHANNEL_WEBDAV_UPLOAD_UPDATE_PROP;
extern NSInteger const ZPFILECHANNEL_WEBDAV_UPLOAD_REGISTER;

@interface ZPFileChannel_WebDAV : ZPFileChannel <UIAlertViewDelegate>{
    NSMutableDictionary* downloadProgressDelegates;
}

@end
