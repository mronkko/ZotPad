//
//  ZPZoteroItemContainer.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/18/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroDataObject.h"

@implementation ZPZoteroDataObject

@synthesize key = _key;
@synthesize title =  _title;
@synthesize libraryID =_libraryID;
@synthesize hasChildren=_hasChildren;
@synthesize cacheTimestamp = _cacheTimestamp;
@synthesize serverTimestamp = _serverTimestamp;
@synthesize numItems = _numItems;

/*
 
 Sub classes need to implement this method that creates and caches data objects.
 
 */

+(id) dataObjectWithKey:(NSObject*) key{
    [NSException raise:@"Not implemented" format:@"Subclasses of ZPZoteroDataObject need to implement dataObjectWithKey method"];
    return nil;
}

+(id) dataObjectWithDictionary:(NSDictionary*) fields{
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
            [self performSelector:NSSelectorFromString(setterString) withObject:[dictionary objectForKey:key]];
        }
    }
}

- (BOOL)isEqual:(id)anObject{
    if([anObject isKindOfClass:[self class]]){
        if(_key == nil) return [_libraryID isEqualToString:[(ZPZoteroDataObject*) anObject libraryID]];
        else return [_key isEqualToString:[(ZPZoteroDataObject*) anObject key]];
    }
    else return FALSE;
}

-(BOOL) needsToBeWrittenToCache{
    return ! [_serverTimestamp isEqualToString:_cacheTimestamp];
}

@end
