//
//  ZPZoteroNote.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/27/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroItem.h"

@interface ZPZoteroNote : ZPZoteroDataObject{
    __strong NSString* _parentItemKey;
}

@property (retain) NSString* parentItemKey;
@property (retain) NSString* itemKey;

// An alias for setParentItemKey
- (void) setParentKey:(NSString*)key;

+(ZPZoteroNote*) noteWithKey:(NSString*) key;
+(ZPZoteroNote*) noteWithDictionary:(NSDictionary*) fields;

@end
