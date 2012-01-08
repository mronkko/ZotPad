//
//  ZPPreferences.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPPreferences.h"
#import "ZPLogger.h"
@implementation ZPPreferences

static ZPPreferences* _instance = nil;

-(id) init{
    self = [super init];

    _metadataCacheLevel = [[NSUserDefaults standardUserDefaults] integerForKey:@"preemptivecachemetadata"];
    
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
    return _metadataCacheLevel >=1;
}


@end
