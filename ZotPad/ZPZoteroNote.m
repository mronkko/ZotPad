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


static NSCache* _objectCache = NULL;

+(ZPZoteroNote*) ZPZoteroNoteWithKey:(NSString*) key{
    
    if(key == NULL)
        [NSException raise:@"Key is null" format:@"ZPZoteroNote cannot be instantiated with NULL key"];
    
    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroNote* obj= [_objectCache objectForKey:key];
    
    if(obj==NULL){
        obj= [[ZPZoteroNote alloc] init];
        obj->_key=key;
        [_objectCache setObject:obj  forKey:key];
    }
    return obj;
}


// An alias for setParentCollectionKey
- (void) setParentKey:(NSString*)key{
    [self setParentItemKey:key];    
}
@end
