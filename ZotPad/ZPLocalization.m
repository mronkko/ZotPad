//
//  ZPLocalization.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/31/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPLocalization.h"
#import "ZPDatabase.h"

@implementation ZPLocalization

static NSCache* localizationCache = NULL;

+ (NSString*) getLocalizationStringWithKey:(NSString*) key type:(NSString*) type locale:(NSString*) locale{
    
    if(localizationCache == NULL) localizationCache = [[NSCache alloc] init ];
    
    NSString* combinedKey = [type stringByAppendingString:key];
    
    NSString* localizationString = [localizationCache objectForKey:combinedKey];
    
    if(localizationString == NULL){
        localizationString = [[ZPDatabase instance] getLocalizationStringWithKey:key type:type locale:locale];
        [localizationCache setObject:localizationString forKey:combinedKey];
    }
    
    return localizationString;
}

@end

