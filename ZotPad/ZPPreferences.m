//
//  ZPPreferences.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPPreferences.h"

@implementation ZPPreferences

static ZPPreferences* _instance = nil;

-(id) init{
    self = [super init];

    _metadataCacheLevel = [[NSUserDefaults standardUserDefaults] integerForKey:@"preemptivecachemetadata"];
    _smartCache = [[NSUserDefaults standardUserDefaults] boolForKey:@"smartcache"];
    
    return self;
}

/*
 Singleton accessor
 */

+(ZPPreferences*) instance {
    if(_instance == NULL){
        _instance = [[ZPPreferences alloc] init];
    }
    return _instance;
}


//        "preemptivecachemetadata" "off" "activecollections" "activelibraries" "alllibraries"
//        "preemptivecacheattachmentfiles" "off" "activeitems" "activecollections" "activelibraries" "alllibraries"


-(BOOL) cacheAllLibraries{
    return _metadataCacheLevel >=3;
}

-(BOOL) cacheActiveLibrary{
    return _metadataCacheLevel >=2;
}
-(BOOL) cacheActiveCollection{
    return _metadataCacheLevel >=2;
}
-(BOOL) smartCache{
    return _smartCache;
}


@end
