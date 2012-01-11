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
    
    [self reload];

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



-(void) reload {
   
    //Read the defaults preferences and set these if no preferences are set.
    
    NSString *settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    if(!settingsBundle) {
        NSLog(@"Could not find Settings.bundle");
        return;
    }
    
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:@"Root.plist"]];
    NSArray *preferences = [settings objectForKey:@"PreferenceSpecifiers"];
    
    NSMutableDictionary *defaultsToRegister = [[NSMutableDictionary alloc] initWithCapacity:[preferences count]];
    for(NSDictionary *prefSpecification in preferences) {
        NSString *key = [prefSpecification objectForKey:@"Key"];
        if(key) {
            [defaultsToRegister setObject:[prefSpecification objectForKey:@"DefaultValue"] forKey:key];
        }
    }
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsToRegister];

    _metadataCacheLevel = [[NSUserDefaults standardUserDefaults] integerForKey:@"preemptivecachemetadata"];
    _mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"mode"];

    NSLog(@"NSUserDefaults dump: %@",[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]);
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

-(BOOL) useCache{
    return (_mode != 0);
}

-(BOOL) online{
    return (_mode != 2);
    
}


@end
