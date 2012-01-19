//
//  ZPLogger.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 1/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ZPLogger.h"

// Set up custom logging for the application
#define NSLog(format, ...) ZPLog(self,__LINE__,format, ## __VA_ARGS__)


@implementation ZPLogger

static NSDate* timeWhenAppStarted;
static NSMutableArray* debugClasses;

void ZPLog(NSObject* source,int line,NSString* format, ...){

    //Write the names of classes that you want to debug in this array.
    if(debugClasses == NULL){
        timeWhenAppStarted = [NSDate date]; 
        debugClasses = [NSMutableArray array ];
        
//        [debugClasses addObject:@"ZPServerConnection"];
//        [debugClasses addObject:@"ZPSimpleItemListViewController"];
        [debugClasses addObject:@"ZPDetailedItemListViewController"];
//        [debugClasses addObject:@"ZPServerResponseXMLParser"];
//        [debugClasses addObject:@"ZPPreferences"];
//        [debugClasses addObject:@"ZPCacheController"];
        [debugClasses addObject:@"ZPDataLayer"];
        [debugClasses addObject:@"ZPAppDelegate"];
//        [debugClasses addObject:@"ZPDatabase"];
//        [debugClasses addObject:@"ZPAuthenticationDialog"];
//        [debugClasses addObject:@"ZPFileThumbnailAndQuicklookController"];
        [debugClasses addObject:@"ZPItemDetailViewController"];
//        [debugClasses addObject:@"ZPFileThumbnailAndQuicklookController"];
  
        
        
    }

    
    NSString* name = NSStringFromClass([source class]);
    if(! [name hasPrefix:@"ZP"] || [debugClasses containsObject:name]){
        
        NSTimeInterval milliseconds = -([timeWhenAppStarted timeIntervalSinceNow] * 1000);
//        NSString* logPrefix = [NSString stringWithFormat:@"%i - %@:%i ",milliseconds,name,line];
        NSString* logPrefix = [NSString stringWithFormat:@"\n\n%f - ",milliseconds];
        logPrefix = [logPrefix stringByAppendingString:name];
        logPrefix = [logPrefix stringByAppendingFormat:@":%i ",line];
        
        va_list args;
        va_start(args,format);
        
        NSString* message = [logPrefix stringByAppendingString:[[NSString alloc] initWithFormat:format arguments:args]];
        va_end(args);
        
        
        fprintf(stderr,"%s",[message UTF8String]);
    }
}


@end
