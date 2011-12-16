//
//  ZPZoteroCollection.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroCollection.h"

@implementation ZPZoteroCollection

@synthesize name;
@synthesize libraryID;
@synthesize collectionKey;
@synthesize parentCollectionKey;
@synthesize hasChildren;


// An alias for setCollectionKey
- (void) setKey:(NSString*)key{
    [self setCollectionKey:key];
}

// An alias for setParentCollectionKey
- (void) setParentKey:(NSString*)key{
    [self setParentCollectionKey:key];    
}

- (void) setTitle:(NSString*)title{
    [self setName:title];
}
                                   

@end
