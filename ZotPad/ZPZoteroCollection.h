//
//  ZPZoteroCollection.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroItemContainer.h"

@interface ZPZoteroCollection : ZPZoteroItemContainer{
    NSString* _parentCollectionKey;
}
@property (retain, nonatomic) NSString* parentCollectionKey;

-(NSString*) collectionKey;

+(ZPZoteroCollection*) ZPZoteroCollectionWithKey:(NSString*) key;
+(void) dropCache;


@end
