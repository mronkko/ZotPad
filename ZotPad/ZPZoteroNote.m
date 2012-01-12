//
//  ZPZoteroNote.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroNote.h"

@implementation ZPZoteroNote

@synthesize parentItemKey = _parentItemKey;

// An alias for setParentCollectionKey
- (void) setParentKey:(NSString*)key{
    [self setParentItemKey:key];    
}
@end
