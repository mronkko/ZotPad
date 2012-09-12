//
//  ZPZoteroItemContainer.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/18/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

@implementation ZPZoteroDataObject

@synthesize key, title, libraryID, cacheTimestamp, serverTimestamp, dateAdded, etag,jsonFromServer,parentKey;
@synthesize numChildren;

// This is very useful for troubleshooting, but because of memory issues, is only used for debug builds
#ifdef ZPDEBUG
//@synthesize responseDataFromWhichThisItemWasCreated;
#endif

/*
 
 Sub classes need to implement this method that creates and caches data objects.
 
 */

+(ZPZoteroDataObject*) itemWithKey:(NSObject*) key{
    [NSException raise:@"Not implemented" format:@"Subclasses of ZPZoteroDataObject need to implement itemWithKey method"];
    return nil;
}

+(ZPZoteroDataObject*) itemWithDictionary:(NSDictionary*) fields{
    [NSException raise:@"Not implemented" format:@"Subclasses of ZPZoteroDataObject need to implement itemWithDictionary method"];
    return nil;
}

/*
 
 */

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

-(BOOL) needsToBeWrittenToCache{
    NSString* ts1 = self.cacheTimestamp;
    NSString* ts2 = self.serverTimestamp;
    BOOL write = ! [ts2 isEqualToString:ts1];
    return write;
}
-(BOOL) hasChildren{
    return self.numChildren >0;
}

/*
 
 Ignore undefined keys
 
 */

- (void)setValue:(id)value forUndefinedKey:(NSString *)aKey{
   // NSLog(@"Cannot set %@ to %@",aKey,value);
}

/*
 
 Set atomic values to zero when nil is used
 
 */

- (void)setNilValueForKey:(NSString *)key{
    
}

@end
