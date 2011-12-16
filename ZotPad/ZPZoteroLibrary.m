//
//  ZPZoteroLibrary.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroLibrary.h"

@implementation ZPZoteroLibrary

@synthesize name;
@synthesize libraryID;
@synthesize hasChildren;

- (void) setKey:(NSString*)key{
    [self setLibraryID:[key intValue]];
}

- (void) setTitle:(NSString*)title{
    [self setName:title];
}

/*
 This is required for conforming to the ZPNavigatorNode protocol
*/

-(NSString*) collectionKey{
    return NULL;
}


@end
