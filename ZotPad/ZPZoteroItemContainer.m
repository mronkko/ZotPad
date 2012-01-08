//
//  ZPZoteroItemContainer.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/18/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroItemContainer.h"

@implementation ZPZoteroItemContainer

@synthesize title =  _title;
@synthesize libraryID =_libraryID;
@synthesize hasChildren=_hasChildren;
@synthesize lastCompletedCacheTimestamp = _lastCompletedCacheTimestamp;
@synthesize serverTimestamp = _serverTimestamp;
@synthesize numItems = _numItems;

-(NSString*) collectionKey{
    return NULL;
}


@end
