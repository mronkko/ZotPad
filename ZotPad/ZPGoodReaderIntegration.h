//
//  ZPGoodReaderIntegration.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 4/27/13.
//
//

#import <Foundation/Foundation.h>
#import "ZPCore.h"


@interface ZPGoodReaderIntegration : NSObject

+(BOOL) takeOverIncomingURLRequest:(NSURL*) url;
+(BOOL) isGoodReaderAppInstalled;
+(void) sendAttachmentToGoodReader:(ZPZoteroAttachment*) attachment;

@end
