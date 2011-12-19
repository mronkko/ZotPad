//
//  ZPZoteroCollection.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroCollection.h"

@implementation ZPZoteroCollection

@synthesize parentCollectionKey=_parentCollectionKey;

static NSCache* _objectCache = NULL;

+(ZPZoteroCollection*) ZPZoteroCollectionWithKey:(NSString*) key{
    
    if(key == NULL)
        [NSException raise:@"Key is null" format:@"ZPZoteroCollection cannot be instantiated with NULL key"];

    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroCollection* obj= [_objectCache objectForKey:key];
    
    if(obj==NULL){
        obj= [[ZPZoteroCollection alloc] init];
        obj->_key = key;
        [_objectCache setObject:obj  forKey:key];
    }
    return obj;
}

-(NSString*) collectionKey{
    return _key;
}
// An alias for setParentCollectionKey
- (void) setParentKey:(NSString*)key{
    [self setParentCollectionKey:key];    
}
                                   

@end
