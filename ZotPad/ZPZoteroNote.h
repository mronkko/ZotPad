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
}

@property (retain) NSString* itemKey;

+(ZPZoteroNote*) noteWithKey:(NSString*) key;
+(ZPZoteroNote*) noteWithDictionary:(NSDictionary*) fields;

@end
