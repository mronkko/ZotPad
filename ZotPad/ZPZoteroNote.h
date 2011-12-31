//
//  ZPZoteroNote.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPZoteroNote : NSObject{
    NSString* _key;
    NSString* _lastTimestamp;
    NSString* _parentItemKey;
}

@property (retain) NSString* lastTimestamp;
@property (retain) NSString* parentItemKey;


+(ZPZoteroNote*) ZPZoteroNoteWithKey:(NSString*) key;
-(NSString*)key;

// An alias for setParentItemKey
- (void) setParentKey:(NSString*)key;

@end
