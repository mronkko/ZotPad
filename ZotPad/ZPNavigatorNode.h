//
//  ZPNavigatorNode.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/16/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPNavigatorNode : NSObject

@property (retain) NSString* name;
@property (assign) NSInteger libraryID;
@property (assign) NSInteger collectionID; 
@property (assign) BOOL hasChildren;


@end
