//
//  ZPZoteroNote.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/27/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"


@implementation ZPZoteroNote

@synthesize note;

+(void)initialize{
    _objectCache =  [[NSCache alloc] init];
}

static NSCache* _objectCache = NULL;



+(ZPZoteroNote*) noteWithDictionary:(NSDictionary *)fields{
    
    NSString* key = [fields objectForKey:ZPKEY_ITEM_KEY];
    
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
-(void) setItemKey:(NSString *)itemKey{
    [super setKey:itemKey];
}
-(NSString*)itemKey{
    return [super key];
}

- (NSInteger) libraryID{
    //Child notes
    if(super.libraryID==ZPLIBRARY_ID_NOT_SET){
        if(self.parentKey != NULL){
            return [ZPZoteroItem itemWithKey:self.parentKey].libraryID;
        }
        else {
            [NSException raise:@"Internal consistency error" format:@"Standalone items must have library IDs. Standalone note with key %@ had a null library ID",self.key];
            return ZPLIBRARY_ID_NOT_SET;
        }
    }
    else{
        //Standalone notes
        return super.libraryID;
    }
}

-(void) setParentKey:(NSString *)parentKey{
    if(parentKey != nil && ! [parentKey isKindOfClass:[NSString class]]){
        [NSException raise:@"Internal consistency exception" format:@"Trying to set a non-string parent key (%@) for note %@",parentKey,self];
    }
    [super setParentKey:parentKey];
}
-(BOOL)locallyAdded{ return FALSE;}
-(BOOL)locallyModified{ return FALSE;}
-(BOOL)locallyDeleted{ return FALSE;}


@end
