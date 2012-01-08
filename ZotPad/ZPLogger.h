//
//  ZPLogger.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 1/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

// Set up custom logging for the application
#define NSLog(format, ...) ZPLog(self,__LINE__,format, ## __VA_ARGS__)


@interface ZPLogger : NSObject

void ZPLog(NSObject* source,int line,NSString* format, ...);

@end
