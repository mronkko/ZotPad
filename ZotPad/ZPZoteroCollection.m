//
//  ZPZoteroCollection.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//


#import "ZPCore.h"
#import "ZPDatabase.h"

@implementation ZPZoteroCollection

@synthesize parentCollectionKey;

static NSCache* _objectCache = NULL;

+(ZPZoteroCollection*) collectionWithDictionary:(NSDictionary*) fields{
    
    NSString* key = [fields objectForKey:@"collectionKey"];
    
    if(key == NULL){
        [NSException raise:@"Key is null" format:@"ZPZoteroCollection cannot be instantiated with NULL key"];
    }
    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroCollection* obj= [_objectCache objectForKey:key];
    
    if(obj==NULL){
        obj= [[ZPZoteroCollection alloc] init];
        obj.key = key;
        [obj configureWithDictionary:fields];
        [_objectCache setObject:obj  forKey:key];
    }
    else [obj configureWithDictionary:fields];

    return obj;

}

+(ZPZoteroCollection*) collectionWithKey:(NSObject*) key{
    
    if(key == NULL){
        [NSException raise:@"Key is null" format:@"ZPZoteroCollection cannot be instantiated with NULL key"];
    }
    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroCollection* obj= [_objectCache objectForKey:key];
    
    if(obj==NULL){
        obj= [[ZPZoteroCollection alloc] init];
        obj.key = (NSString*) key;
        [ZPDatabase addAttributesToCollection:obj];
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

-(NSString *) collectionKey{
    return [self key];
}
-(void) setCollectionKey:(NSString *)collectionKey{
    [self setKey:collectionKey];
}
@end
