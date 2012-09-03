//
//  ZPZoteroCollection.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroDataObject.h"

@interface ZPZoteroCollection : ZPZoteroDataObject{
}
@property (retain) NSString* collectionKey;

+(void) dropCache;
+(ZPZoteroCollection*) collectionWithKey:(NSString*) key;
+(ZPZoteroCollection*) collectionWithDictionary:(NSDictionary*) fields;


@end
