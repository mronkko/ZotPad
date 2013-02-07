//
//  ZPZoteroNote.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/27/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroDataObjectWithNote.h"

@interface ZPZoteroNote : ZPZoteroDataObject <ZPZoteroDataObjectWithNote>{
}

@property (retain) NSString* itemKey;
@property (retain) NSString* note;

+(ZPZoteroNote*) noteWithKey:(NSString*) key;
+(ZPZoteroNote*) noteWithDictionary:(NSDictionary*) fields;

//TODO: Refactor these away. This is a quick an dirty way to clean local edit state
-(BOOL)locallyAdded;
-(BOOL)locallyModified;
-(BOOL)locallyDeleted;

@end
