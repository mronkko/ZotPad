//
//  ZPLocalization.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/31/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPLocalization : NSObject

+ (NSString*) getLocalizationStringWithKey:(NSString*) key type:(NSString*) type locale:(NSString*) locale;
+ (void) dropCache;

@end
