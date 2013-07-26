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

@interface ZPFileChannel_Dropbox : ZPFileChannel <DBRestClientDelegate, DBSessionDelegate, UIAlertViewDelegate>{
    NSMutableDictionary* downloadProgressViewsByAttachment;
    NSMutableDictionary* uploadProgressViewsByAttachment;
    NSMutableDictionary* downloadCountsByAttachment;
    NSMutableDictionary* remoteVersions;
}

+(void)linkDropboxIfNeeded;

@end
