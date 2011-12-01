//
//  ZPItemCacheOperation.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPItemCacheWriteOperation.h"
#import "ZPDataLayer.h"
#import "ZPZoteroItem.h"
#import "ZPDetailViewController.h"

@implementation ZPItemCacheWriteOperation

-(id) initWithZoteroItemArray:(NSArray*)items{
    self = [super init];
    _items= items;
    return self;
}

-(void) main {
    if ( self.isCancelled ) return;
    
    NSEnumerator *e = [_items objectEnumerator];
    id object;
    while ((object = [e nextObject]) && ! self.isCancelled) {
        [[ZPDataLayer instance] addItemToDatabase:(ZPZoteroItem*) object];
        //TODO: Cache collection memberships
        
        //Notify the user interface that this item is now available
        NSString* key = [(ZPZoteroItem*) object key];
        ZPDetailViewController* controller=[ZPDetailViewController instance];
        [controller notifyItemAvailable:key];
    }
}

@end
