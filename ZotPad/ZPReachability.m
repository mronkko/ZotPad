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

    _reach = [Reachability reachabilityWithHostName:@"https://api.zotero.org"];
    
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
        DDLogWarn(@"Connected to Zotero server");
        [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_INTERNET_CONNECTION_AVAILABLE object:NULL];
    }
    else{
        DDLogWarn(@"Lost connection to Zotero server");
    }
}

+(BOOL) hasInternetConnection{
    
    
    Reachability *HostReach = [Reachability reachabilityForInternetConnection];
    NetworkStatus internetStatus = [HostReach currentReachabilityStatus];
    bool result = false;
    if (internetStatus == ReachableViaWiFi)
        result = true;
    else if(internetStatus==ReachableViaWWAN)
        result = true;
    
    BOOL online = [ZPPreferences online];
    
    return online && result;
    //    return _zoteroReachability && online;
}

@end
