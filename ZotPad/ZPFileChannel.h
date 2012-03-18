//
//  ZPFileChannel.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroAttachment.h"
@interface ZPFileChannel : NSObject

- (BOOL) upload:(ZPZoteroAttachment*)attachment;
- (BOOL) download:(ZPZoteroAttachment*)attachment intoTempFile:(NSString*)tempFile withUIProgressView:(UIProgressView*) progressView;

@end
