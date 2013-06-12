//
//  ZPZoteroCollection.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//


#import "ZPCore.h"


@implementation ZPZoteroCollection


static NSCache* _objectCache = NULL;

+(ZPZoteroCollection*) collectionWithDictionary:(NSDictionary*) fields{
    
    NSString* key = [fields objectForKey:ZPKEY_COLLECTION_KEY];
    
    if(key == NULL){
        [NSException raise:@"Key is null" format:@"ZPZoteroCollection cannot be instantiated with NULL key"];
    }
    if([(NSString*)key length] != 8){
        [NSException raise:@"Key is not valid" format:@"ZPZoteroCollection key must be 8 characters"];
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
    if([(NSString*)key length] != 8){
        [NSException raise:@"Key is not valid" format:@"ZPZoteroCollection key must be 8 characters"];
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


-(void) setCollectionKey:(NSString *)itemCollection{
    [super setKey:itemCollection];
}
-(NSString*)collectionKey{
    return [super key];
}
@end
