//
//  ZPZoteroNote.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/27/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroItem.h"

@interface ZPZoteroNote : ZPZoteroItem{
    __strong NSString* _parentItemKey;
}

@property (retain) NSString* parentItemKey;


// An alias for setParentItemKey
- (void) setParentKey:(NSString*)key;

@end
