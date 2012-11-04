//
//  ZPFileChannel_ZoteroStorage.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPFileChannel.h"
#import "ASIHTTPRequestDelegate.h"

extern NSInteger const ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_AUTHORIZATION;
extern NSInteger const ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_FILE;
extern NSInteger const ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_REGISTER;
extern NSInteger const ZPFILECHANNEL_ZOTEROSTORAGE_DOWNLOAD;


@interface ZPFileChannel_ZoteroStorage : ZPFileChannel <ASIHTTPRequestDelegate, UIAlertViewDelegate>{
    BOOL _alertVisible;
}

@end
