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

+(ZPZoteroLibrary*) ZPZoteroLibraryWithID:(NSNumber*) libraryID{

    if(libraryID == NULL)
        [NSException raise:@"ID is null" format:@"ZPZoteroLibrary cannot be instantiated with NULL ID"];

    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
  
    ZPZoteroLibrary* obj= [_objectCache objectForKey:libraryID];
    
    if(obj==NULL){
        obj= [[ZPZoteroLibrary alloc] init];
        obj->_libraryID=libraryID;
        [[ZPDatabase instance] addFieldsToLibrary:obj];
        [_objectCache setObject:obj  forKey:libraryID];
    }
    
    return obj;
}

+(void) dropCache{
    [_objectCache removeAllObjects];
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

- (BOOL)isEqual:(id)anObject{
    if([anObject isKindOfClass:[self class]]){
        return [[(ZPZoteroLibrary*) anObject libraryID] isEqualToNumber:_libraryID];
    }
        else return FALSE;
}


@end
