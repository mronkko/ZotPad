//
//  ZPZoteroLibrary.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"
#import "ZPDatabase.h"

@implementation ZPZoteroLibrary

static NSCache* _objectCache = NULL;

+(ZPZoteroLibrary*) dataObjectWithDictionary:(NSDictionary*) fields{
    
    NSNumber* libraryID = [fields objectForKey:@"libraryID"];
    
    if(libraryID == NULL)
        [NSException raise:@"ID is null" format:@"ZPZoteroLibrary cannot be instantiated with NULL ID"];
    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroLibrary* obj= [_objectCache objectForKey:libraryID];
    
    if(obj==NULL){
        obj= [[ZPZoteroLibrary alloc] init];
        obj.libraryID=libraryID;
        [obj configureWithDictionary:fields];
        [_objectCache setObject:obj  forKey:libraryID];
    }
    else [obj configureWithDictionary:fields];

    return obj;
}

+(ZPZoteroLibrary*) dataObjectWithKey:(NSObject*) libraryID{

    if(libraryID == NULL)
        [NSException raise:@"ID is null" format:@"ZPZoteroLibrary cannot be instantiated with NULL ID"];

    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
  
    ZPZoteroLibrary* obj= [_objectCache objectForKey:libraryID];
    
    if(obj==NULL){
        obj= [[ZPZoteroLibrary alloc] init];
        obj.libraryID=(NSNumber*)libraryID;

        if([obj.libraryID intValue]==1){
            obj.title = @"My Library";
            [obj setNumChildren:[NSNumber numberWithInt:[[[ZPDatabase instance] collectionsForLibrary:obj.libraryID withParentCollection:NULL] count]]];
        }
        else{
            [[ZPDatabase instance] addAttributesToGroupLibrary:obj];
        }
            
        [_objectCache setObject:obj  forKey:libraryID];
    }
    
    return obj;
}

+(void) dropCache{
    [_objectCache removeAllObjects];
}



@end
