//
//  ZPLocalization.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/31/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPLocalization.h"
#import "ZPDatabase.h"
#import "ZPLogger.h"

@implementation ZPLocalization

static NSCache* localizationCache = NULL;

+ (void) dropCache{
    [localizationCache removeAllObjects];
}

+ (NSString*) getLocalizationStringWithKey:(NSString*) key type:(NSString*) type locale:(NSString*) locale{
    
    if(localizationCache == NULL) localizationCache = [[NSCache alloc] init ];
    
    NSString* combinedKey = [type stringByAppendingString:key];
    
    NSString* localizationString = [localizationCache objectForKey:combinedKey];
    
    if(localizationString == NULL){
        localizationString = [[ZPDatabase instance] getLocalizationStringWithKey:key type:type locale:locale];

        //If there is no localizatio string available, capitalize the first letter of the key and use that.
        
        if(localizationString == NULL){
            localizationString = [key  stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[key substringToIndex:1] uppercaseString]];
        }
        [localizationCache setObject:localizationString forKey:combinedKey];
    }
    
    return localizationString;
}

@end

