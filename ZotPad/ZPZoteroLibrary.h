//
//  ZPZoteroLibrary.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroDataObject.h"

@interface ZPZoteroLibrary : ZPZoteroDataObject {
}

+(void) dropCache;
-(NSNumber*) groupID;

@end