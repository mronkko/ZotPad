//
//  ZPZoteroCollection.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroDataObject.h"

@interface ZPZoteroCollection : ZPZoteroDataObject{
    NSString* _parentCollectionKey;
}

@property (retain, nonatomic) NSString* parentCollectionKey;
@property (retain, readonly) NSString* collectionKey;

+(void) dropCache;


@end
