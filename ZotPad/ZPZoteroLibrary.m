//
//  ZPZoteroLibrary.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroLibrary.h"

@implementation ZPZoteroLibrary

static NSCache* _objectCache = NULL;

+(ZPZoteroLibrary*) ZPZoteroLibraryWithID:(NSNumber*) libraryID{

    if(libraryID == NULL)
        [NSException raise:@"ID is null" format:@"ZPZoteroLibrary cannot be instantiated with NULL ID"];

    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
  
    ZPZoteroLibrary* obj= [_objectCache objectForKey:libraryID];
    
    if(obj==NULL){
        obj= [[ZPZoteroLibrary alloc] init];
        obj->_libraryID=libraryID;
        [_objectCache setObject:obj  forKey:libraryID];
    }
    return obj;
}

- (NSNumber*) libraryID{
    return _libraryID;
}

/*
 This is required for conforming to the ZPNavigatorNode protocol
*/

-(NSString*) collectionKey{
    return NULL;
}


@end
