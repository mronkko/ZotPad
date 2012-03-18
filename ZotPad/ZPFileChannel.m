//
//  ZPFileChannel.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPFileChannel.h"
#import "ZPZoteroAttachment.h"

@implementation ZPFileChannel

- (BOOL) upload:(ZPZoteroAttachment*)attachment{
    return false;
}

- (BOOL) download:(ZPZoteroAttachment*)attachment intoTempFile:(NSString*)tempFile{
    return false;
}

@end
