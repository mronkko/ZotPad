//
//  ZPZoteroItemContainer.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/18/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPCore.h"

@implementation ZPZoteroDataObject

@synthesize key, title, libraryID, cacheTimestamp, serverTimestamp;

// This is very useful for troubleshooting, but because of memory issues, is only used for debug builds
#ifdef DEBUG
@synthesize responseDataFromWhichThisItemWasCreated;
#endif

/*
 
 Sub classes need to implement this method that creates and caches data objects.
 
 */

+(ZPZoteroDataObject*) dataObjectWithKey:(NSObject*) key{
    [NSException raise:@"Not implemented" format:@"Subclasses of ZPZoteroDataObject need to implement dataObjectWithKey method"];
    return nil;
}

+(ZPZoteroDataObject*) dataObjectWithDictionary:(NSDictionary*) fields{
    [NSException raise:@"Not implemented" format:@"Subclasses of ZPZoteroDataObject need to implement dataObjectWithDictionary method"];
    return nil;
}

/*
 
 */

-(void) configureWithDictionary:(NSDictionary*) dictionary{
    
    
    for(NSString* key in dictionary){
 
        //capitalize the first letter
        NSString* setterString = [key stringByReplacingCharactersInRange:NSMakeRange(0,1)  
                                                             withString:[[key substringToIndex:1] capitalizedString]];
        
        //Make a setter and use it if it exists
        setterString = [[@"set" stringByAppendingString:setterString]stringByAppendingString: @":"];
        if([self respondsToSelector:NSSelectorFromString(setterString)]){
            NSObject* value=[dictionary objectForKey:key];
            [self performSelector:NSSelectorFromString(setterString) withObject:value];
        }
    }
}

- (BOOL)isEqual:(id)anObject{
    if([anObject isKindOfClass:[self class]]){
        if(self.key == nil) return [self.libraryID isEqual:[(ZPZoteroDataObject*) anObject libraryID]];
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
    return _numChildren>0;
}

-(NSNumber*) numChildren{
    return [NSNumber numberWithInt: _numChildren];
}
-(void) setNumChildren:(NSNumber*) numChildren {
    _numChildren = [numChildren intValue];
}

@end
