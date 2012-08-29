//
//  ZPZoteroNote.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/27/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"
#import "ZPDatabase.h"

@implementation ZPZoteroNote

@synthesize itemKey, parentItemKey;

+(void)initialize{
    _objectCache =  [[NSCache alloc] init];
}

static NSCache* _objectCache = NULL;

+(ZPZoteroNote*) noteWithDictionary:(NSDictionary *)fields{
    
    NSString* key = [fields objectForKey:@"itemKey"];
    
    if(key == NULL || [key isEqual:@""])
        [NSException raise:@"Key is empty" format:@"ZPZoteroNote cannot be instantiated with empty key"];
    
    ZPZoteroNote* note = (ZPZoteroNote*) [_objectCache objectForKey:key];
    
    if(note == NULL){
        note = [[ZPZoteroNote alloc] init];
    }
    
    [note configureWithDictionary:fields];
    
    return note;
}

+(ZPZoteroNote*) noteWithKey:(NSString *)key{
    
    if(key == NULL || [key isEqual:@""])
        [NSException raise:@"Key is empty" format:@"ZPZoteroNote cannot be instantiated with empty key"];
    
    ZPZoteroNote* note = (ZPZoteroNote*) [_objectCache objectForKey:key];
    
    if(note == NULL){
        note = [ZPZoteroNote noteWithDictionary:[ZPDatabase attributesForNoteWithKey:key]];
    }
    
    return note;
    
}
// An alias for setParentCollectionKey
- (void) setParentKey:(NSString*)key{
    [self setParentItemKey:key];    
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
