//
//  ZPZoteroLibrary.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPNavigatorNode.h"

@interface ZPZoteroLibrary : NSObject <ZPNavigatorNode> {
    NSString* name;
    NSInteger libraryID;
    //Does the library have any collections
    BOOL hasChildren;
}

@property (retain) NSString* name;
@property (assign) NSInteger libraryID;
@property (assign) BOOL hasChildren;

// An aliases used by parser
- (void) setKey:(NSString*)key;
- (void) setTitle:(NSString*)title;

// Needed for the ZPNavigatorNode protocol
- (NSInteger)collectionID;

@end


