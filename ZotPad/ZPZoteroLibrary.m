//
//  ZPZoteroLibrary.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"
#import "ZPDatabase.h"

NSInteger const LIBRARY_ID_MY_LIBRARY = -1;
NSInteger const LIBRARY_ID_NOT_SET = 0;

@implementation ZPZoteroLibrary

static NSCache* _objectCache = NULL;

+(void)initialize{
    _objectCache = [[NSCache alloc] init];
}

+(ZPZoteroLibrary*) libraryWithDictionary:(NSDictionary*) fields{
    
    NSNumber* libraryIDObj = [fields objectForKey:@"libraryID"];
    
    if(libraryIDObj == NULL || [libraryIDObj integerValue] == LIBRARY_ID_NOT_SET)
        [NSException raise:@"ID is null" format:@"ZPZoteroLibrary cannot be instantiated with NULL ID"];
    
    NSInteger libraryID = [libraryIDObj integerValue];
    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroLibrary* obj= [_objectCache objectForKey:libraryIDObj];
    
    if(obj==NULL){
        obj= [[ZPZoteroLibrary alloc] init];
        obj.libraryID=libraryID;
        [obj configureWithDictionary:fields];
        [_objectCache setObject:obj forKey:libraryIDObj];
    }
    else [obj configureWithDictionary:fields];

    return obj;
}

+(ZPZoteroLibrary*) libraryWithID:(NSInteger)libraryID{

    if(libraryID == LIBRARY_ID_NOT_SET)
        [NSException raise:@"ID is not set" format:@"ZPZoteroLibrary cannot be instantiated with undefined ID"];

    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];

    
    ZPZoteroLibrary* obj= [_objectCache objectForKey:[NSNumber numberWithInt:libraryID]];
    
    if(obj==NULL){
        obj= [[ZPZoteroLibrary alloc] init];
        obj.libraryID=libraryID;

        if(obj.libraryID == LIBRARY_ID_MY_LIBRARY){
            obj.title = @"My Library";
            [obj setNumChildren:[[ZPDatabase collectionsForLibrary:obj.libraryID withParentCollection:NULL] count]];
        }
        else{
            [ZPDatabase addAttributesToGroupLibrary:obj];
        }
            
        [_objectCache setObject:obj  forKey:[NSNumber numberWithInt:libraryID]];
    }
    
    return obj;
}

+(void) dropCache{
    [_objectCache removeAllObjects];
}



@end
