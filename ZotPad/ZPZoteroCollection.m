//
//  ZPZoteroCollection.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroCollection.h"
#import "ZPDatabase.h"

@implementation ZPZoteroCollection

@synthesize parentCollectionKey=_parentCollectionKey;
@synthesize collectionKey=_collectionKey;

static NSCache* _objectCache = NULL;

+(id) dataObjectWithDictionary:(NSDictionary*) fields{
    
    NSString* key = [fields objectForKey:@"collectionKey"];
    
    if(key == NULL)
        [NSException raise:@"Key is null" format:@"ZPZoteroCollection cannot be instantiated with NULL key"];
    
    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroCollection* obj= [_objectCache objectForKey:key];
    
    if(obj==NULL){
        obj= [[ZPZoteroCollection alloc] init];
        obj->_key = key;
        [obj configureWithDictionary:fields];
        [_objectCache setObject:obj  forKey:key];
    }
    else [obj configureWithDictionary:fields];

    return obj;

}

+(ZPZoteroCollection*) dataObjectWithKey:(NSObject*) key{
    
    if(key == NULL)
        [NSException raise:@"Key is null" format:@"ZPZoteroCollection cannot be instantiated with NULL key"];

    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroCollection* obj= [_objectCache objectForKey:key];
    
    if(obj==NULL){
        obj= [[ZPZoteroCollection alloc] init];
        obj->_key = (NSString*) key;
        [[ZPDatabase instance] addAttributesToCollection:obj];
        [_objectCache setObject:obj  forKey:key];
    }
    return obj;
}

+(void) dropCache{
    [_objectCache removeAllObjects];
}

// An alias for setParentCollectionKey
- (void) setParentKey:(NSString*)key{
    [self setParentCollectionKey:key];    
}
                                   
@end
