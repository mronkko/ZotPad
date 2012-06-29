//
//  ZPFileChannel_WebDAV.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPFileChannel.h"


extern NSInteger const ZPFILECHANNEL_WEBDAV_DOWNLOAD;
extern NSInteger const ZPFILECHANNEL_WEBDAV_UPLOAD_FILE;
extern NSInteger const ZPFILECHANNEL_WEBDAV_UPLOAD_REGISTER;

@interface ZPFileChannel_WebDAV : ZPFileChannel <UIAlertViewDelegate>{
    NSMutableDictionary* downloadProgressDelegates;
}

@end
