//
//  ZPZoteroLibrary.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroLibrary.h"
#import "ZPDatabase.h"

@implementation ZPZoteroLibrary

static NSCache* _objectCache = NULL;

+(ZPZoteroLibrary*) dataObjectWithKey:(NSString*) libraryID{

    if(libraryID == NULL)
        [NSException raise:@"ID is null" format:@"ZPZoteroLibrary cannot be instantiated with NULL ID"];

    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
  
    ZPZoteroLibrary* obj= [_objectCache objectForKey:libraryID];
    
    if(obj==NULL){
        obj= [[ZPZoteroLibrary alloc] init];
        obj->_libraryID=libraryID;
        [[ZPDatabase instance] addFieldsToGroupLibrary:obj];
        [_objectCache setObject:obj  forKey:libraryID];
    }
    
    return obj;
}

+(void) dropCache{
    [_objectCache removeAllObjects];
}



@end
