//
//  ZPItemCacheOperation.h
//  ZotPad
//
//
//  Writes the details of the ZPZoteroItems into cache
//
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPItemCacheWriteOperation : NSOperation{
    NSArray* _items;
}
-(id) initWithZoteroItemArray:(NSArray*)items;

@end
