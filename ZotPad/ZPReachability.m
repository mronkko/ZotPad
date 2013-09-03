//
//  ZPReachability.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 1/6/13.
//
//

#import "ZPCore.h"
#import "ZPReachability.h"
#import "Reachability.h"

@implementation ZPReachability

static Reachability* _reach;
static BOOL _zoteroReachability;

+(void) initialize {

    _reach = [Reachability reachabilityForInternetConnection];
    
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    [_reach startNotifier];
}

+ (void) reachabilityChanged:(NSNotification *)notification
{
    Reachability *localReachability = [notification object];
    
    _zoteroReachability = [localReachability isReachable];
    if (_zoteroReachability){
        DDLogWarn(@"Connected to internet");
        [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_INTERNET_CONNECTION_AVAILABLE object:NULL];
    }
    else{
        DDLogWarn(@"Lost internet connection");
    }
}

+(BOOL) hasInternetConnection{
    
    
    // This provide false negative results.
    
    BOOL hasConnection = [_reach isReachable];
    BOOL online = [ZPPreferences online];
    
    return online && hasConnection;
     
}

@end
