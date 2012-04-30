//
//  ZPFileChannel_WebDAV.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPFileChannel.h"

@interface ZPFileChannel_WebDAV : ZPFileChannel <UIAlertViewDelegate>{
    NSMutableDictionary* progressDelegates;
}

@end
