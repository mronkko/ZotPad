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

-(NSInteger) collectionID{
    return 0;
}


@end
