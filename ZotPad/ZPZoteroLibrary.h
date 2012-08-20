//
//  ZPZoteroLibrary.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroDataObject.h"


extern NSInteger const LIBRARY_ID_MY_LIBRARY;
extern NSInteger const LIBRARY_ID_NOT_SET;

@interface ZPZoteroLibrary : ZPZoteroDataObject {
}

+(void) dropCache;
+(ZPZoteroLibrary*) libraryWithID:(NSInteger) libraryID;
+(ZPZoteroLibrary*) libraryWithDictionary:(NSDictionary*) fields;

@end