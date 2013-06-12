//
//  ZPZoteroItemContainer.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/18/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

@implementation ZPZoteroDataObject

@synthesize title, libraryID, cacheTimestamp, serverTimestamp, dateAdded, etag,jsonFromServer,parentKey;
@synthesize numChildren, needsToBeWrittenToCache;
@synthesize locallyAdded, locallyDeleted, locallyModified;


// This is very useful for troubleshooting, but because of memory issues, is only used for debug builds
#ifdef ZPDEBUG
//@synthesize responseDataFromWhichThisItemWasCreated;
#endif

//@synthesize key

-(void) setKey:(NSString *)key{
    NSAssert([key length] == 8, @"Data object keys must be 8 characters");
    _key = key;
}
-(NSString*) key{
    return _key;
}

-(void) configureWithDictionary:(NSDictionary*) dictionary{
    [self setValuesForKeysWithDictionary:dictionary];
}

- (BOOL)isEqual:(id)anObject{
    if([anObject isKindOfClass:[self class]]){
        if(self.key == nil) return self.libraryID == [(ZPZoteroDataObject*) anObject libraryID];
        else return [self.key isEqualToString:[(ZPZoteroDataObject*) anObject key]];
    }
    else return FALSE;
}

-(BOOL) hasChildren{
    return self.numChildren >0;
}

-(NSArray*) tags{
    if(_tags == NULL){
        [ZPDatabase addTagsToDataObject:self];
    }
    return  _tags;
}

-(void)setTags:(NSArray *)tags{
    _tags = tags;
}

/*
 
 Ignore undefined keys
 
 */

- (void)setValue:(id)value forUndefinedKey:(NSString *)aKey{
   // //NSLog(@"Cannot set %@ to %@",aKey,value);
}

/*
 
 Set atomic values to zero when nil is used
 
 */

- (void)setNilValueForKey:(NSString *)key{
    
}


- (NSString *)description{
    return [NSString stringWithFormat:@"Zotero data object. Class: %@, Key: %@, LibraryID: %i",
            NSStringFromClass([self class]), self.key, self.libraryID];
}

@end
