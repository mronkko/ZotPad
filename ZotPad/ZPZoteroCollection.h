//
//  ZPZoteroCollection.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPNavigatorNode.h"

@interface ZPZoteroCollection : NSObject <ZPNavigatorNode>{
    NSString* name;
    NSString* collectionKey;
    NSString* parentCollectionKey;
    NSInteger libraryID;
    NSInteger collectionID; 
    BOOL hasChildren;
}

@property (retain) NSString* name;
@property (retain) NSString* collectionKey;
@property (retain) NSString* parentCollectionKey;
@property (assign) NSInteger libraryID;
@property (assign) NSInteger collectionID; 
@property (assign) BOOL hasChildren;

// An alias for setCollectionKey
- (void) setKey:(NSString*)key;

// An alias for setParentCollectionKey
- (void) setParentKey:(NSString*)key;

- (void) setTitle:(NSString*)title;

@end
