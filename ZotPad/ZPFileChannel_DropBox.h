//
//  ZPFileChannel_DropBox.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DropboxSDK/DropboxSDK.h>
#import "ZPFileChannel.h"
@interface ZPFileChannel_Dropbox : ZPFileChannel <DBRestClientDelegate>{
    NSMutableDictionary* progressViewsByRequest;
    NSMutableDictionary* downloadCountsByRequest;

}

@end
