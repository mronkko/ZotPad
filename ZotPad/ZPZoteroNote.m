//
//  ZPZoteroNote.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/27/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

@implementation ZPZoteroNote

+(id) dataObjectWithDictionary:(NSDictionary *)fields{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:fields ];
    [dict setObject:@"note" forKey:@"itemType"];
    return [super dataObjectWithDictionary:dict];
}

// An alias for setParentCollectionKey
- (void) setParentKey:(NSString*)key{
    [self setParentItemKey:key];    
}

- (void) setParentItemKey:(NSString*)key{
    _parentItemKey = key; 
}
- (NSString*) parentItemKey{
    if(_parentItemKey == NULL){
        return self.key;
    }
    else{
        return _parentItemKey;
    }
}

- (NSArray*) creators{
    return [NSArray array];
}
- (NSDictionary*) fields{
    return [NSDictionary dictionary];
}

-(NSString*) itemType{
    return @"note";
}


@end
