//
//  ZPPreferences.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPCore.h"

#import "ZPPreferences.h"
#import "ZPLogger.h"
#import "ZPDatabase.h"
#import "ZPCacheController.h"
#import "ASIHTTPRequest.h"

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
   
    NSLog(@"Realoding preferences");
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    
    
    //Read the defaults preferences and set these if no preferences are set.
    
    NSString *settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    if(!settingsBundle) {
        NSLog(@"Could not find Settings.bundle");
        return;
    }
    

    NSMutableDictionary *defaultsToRegister = [[NSMutableDictionary alloc] init];

    NSArray* preferenceFiles = [NSArray arrayWithObjects:@"Root.plist", @"samba.plist", nil];
    
    NSString* preferenceFile;
    for(preferenceFile in preferenceFiles){
        NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:preferenceFile]];
        NSArray *preferences = [settings objectForKey:@"PreferenceSpecifiers"];
        
        for(NSDictionary *prefSpecification in preferences) {
            NSString *key = [prefSpecification objectForKey:@"Key"];
            NSObject* defaultValue = [prefSpecification objectForKey:@"DefaultValue"];
            if(key && defaultValue) {
                [defaultsToRegister setObject:defaultValue forKey:key];
            }
        }
    }    
    [defaults registerDefaults:defaultsToRegister];

    _metadataCacheLevel = [defaults integerForKey:@"preemptivecachemetadata"];
    _attachmentsCacheLevel = [defaults integerForKey:@"preemptivecacheattachmentfiles"];
    _mode = [defaults integerForKey:@"mode"];
    float rawmax = [defaults floatForKey:@"cachesizemax"];
    _maxCacheSize = rawmax*1024*1024;
    
    NSLog(@"NSUserDefaults dump: %@",[defaults dictionaryRepresentation]);
    

}

-(NSString*) defaultApplicationForContentType:(NSString*) type{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:[@"defaultApp_" stringByAppendingString:type]];
}

-(void) setDefaultApplication:(NSString*) application forContentType:(NSString*) type{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults setObject:application forKey:[@"defaultApp_" stringByAppendingString:type]];    
}


-(void) checkAndProcessApplicationResetPreferences{
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    if([defaults boolForKey:@"resetusername"]){
        NSLog(@"Reseting username");
        [self resetUserCredentials];
        [defaults removeObjectForKey:@"resetusername"];
    }
    
    if([defaults boolForKey:@"resetitemdata"]){
        NSLog(@"Reseting itemdata");
        [defaults removeObjectForKey:@"resetitemdata"];
        [[ZPDatabase instance] resetDatabase];
    }
    
    if([defaults boolForKey:@"resetfiles"]){
        NSLog(@"Reseting files");
        [defaults removeObjectForKey:@"resetfiles"];
        [[ZPCacheController instance] performSelectorInBackground:@selector(purgeAllAttachmentFilesFromCache) withObject:NULL];
    }

}
-(void) resetUserCredentials{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"username"];
    [defaults removeObjectForKey:@"userID"];
    [defaults removeObjectForKey:@"OAuthKey"];
    
    //Empty the key chain
    
    NSURLCredentialStorage *store = [NSURLCredentialStorage sharedCredentialStorage];
    for (NSURLProtectionSpace *space in [store allCredentials]) {
        NSDictionary *userCredentialMap = [store credentialsForProtectionSpace:space];
        for (NSString *user in userCredentialMap) {
            NSURLCredential *credential = [userCredentialMap objectForKey:user];
            [store removeCredential:credential forProtectionSpace:space];
        }
    }
    
}
// Max cache size in kilo bytes
-(NSInteger) maxCacheSize{
    return _maxCacheSize;
}

-(BOOL) cacheMetadataAllLibraries{
    return _metadataCacheLevel >=3;
}

-(BOOL) cacheMetadataActiveLibrary{
    return _metadataCacheLevel >=2;
}
-(BOOL) cacheMetadataActiveCollection{
    return _metadataCacheLevel >=1;
}

-(BOOL) cacheAttachmentsAllLibraries{
    return _attachmentsCacheLevel >=4;
}

-(BOOL) cacheAttachmentsActiveLibrary{
    return _attachmentsCacheLevel >=3;
}
-(BOOL) cacheAttachmentsActiveCollection{
    return _attachmentsCacheLevel >=2;
}
-(BOOL) cacheAttachmentsActiveItem{
    return _attachmentsCacheLevel >=1;
}

-(BOOL) useCache{
    return (_mode != 0);
}

-(BOOL) online{
    return (_mode != 2);
}

-(void) setOnline:(BOOL)online{
    if(online) _mode = 1;
    else _mode = 2;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInt:_mode] forKey:@"mode"];
}

-(BOOL) useDropbox{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults objectForKey:@"filechannel"] isEqualToString:@"dropbox"];
}
-(BOOL) useWebDAV{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults objectForKey:@"filechannel"] isEqualToString:@"webdavzotero"];
}
-(void) setUseWebDAV:(BOOL) value{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if(value) [defaults setObject:@"webdavzotero" forKey:@"filechannel"];
    else [defaults setObject:@"zotero" forKey:@"filechannel"];
}

-(NSString*) webDAVURL{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* ret = [[defaults objectForKey:@"webdavurl"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    //String trailing slash
    if([ret hasSuffix:@"/"]){
        ret = [ret substringToIndex:[ret length] - 1];
    }
    return ret;
}

-(NSString*) username{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"username"];
}
-(void) setUsername: (NSString*) value {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:value forKey:@"username"];
}

-(NSString*) userID{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"userID"];
}
-(void) setUserID: (NSString*) value {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:value forKey:@"userID"];
}

-(NSString*) OAuthKey{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"OAuthKey"];
}
-(void) setOAuthKey:(NSString*) value {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:value forKey:@"OAuthKey"];
}

-(NSString*) currentCacheSize{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"cachesizecurrent"];
}
-(void) setCurrentCacheSize:(NSString*) value {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:value forKey:@"cachesizecurrent"];
}

@end
