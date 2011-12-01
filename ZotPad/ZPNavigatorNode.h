//
//  ZPNavigatorNode.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/30/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ZPNavigatorNode <NSObject>

-(BOOL) hasChildren;
-(NSInteger) libraryID;
-(NSInteger) collectionID;
-(NSString*) name;

@end