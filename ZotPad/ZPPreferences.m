//
//  ZPPreferences.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"




#import "ZPFileCacheManager.h"

#import "../InAppSettingsKit/InAppSettingsKit/Models/IASKSettingsReader.h"
#import "../InAppSettingsKit/InAppSettingsKit/Models/IASKSpecifier.h"

@implementation ZPPreferences

static NSInteger _metadataCacheLevel;
static NSInteger _attachmentsCacheLevel;
static NSInteger _mode;
static NSInteger _maxCacheSize;

+(void) initialize{
    [ZPPreferences reload];
}

+(void) reload {
   
    DDLogInfo(@"Reloading settings");
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    //Read the defaults preferences and set these if no preferences are set.
    
    NSString *settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    if(!settingsBundle) {
        DDLogError(@"Could not find Settings.bundle");
        return;
    }
    

    NSMutableDictionary *defaultsToRegister = [[NSMutableDictionary alloc] init];

    NSArray* preferenceFiles = [NSArray arrayWithObjects:@"Root.plist", @"Dropbox.plist", nil];
    
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
    
    // Alert if webdav is misconfigured
    
    if ([self useWebDAV]) {
        NSString* webdavUrl = [self webDAVURL];
        
        if(![webdavUrl hasPrefix:@"http"] || ! [webdavUrl hasSuffix:@"/zotero"]){
            
            NSString* newWebDAVURL = webdavUrl;
            if(! [webdavUrl hasPrefix:@"http"]) newWebDAVURL = [NSString stringWithFormat:@"http://%@",newWebDAVURL];
            if(! [webdavUrl hasSuffix:@"/zotero"]) newWebDAVURL = [NSString stringWithFormat:@"%@/zotero",newWebDAVURL];
            
            [[[UIAlertView alloc] initWithTitle:@"WebDAV configuration error"
                                       message:[NSString stringWithFormat:@"WebDAV is enabled, but the WebDAV address was not specified correctly. The WebDAV address must start with 'http://' or 'https://' and end with '/zotero'. The WebDAV url was '%@' and has been automaticall changed to '%@'",webdavUrl,newWebDAVURL]
                                      delegate:NULL
                             cancelButtonTitle:@"OK"
                              otherButtonTitles: nil] show];
            
            NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:newWebDAVURL forKey:@"webdavurl"];

        }

    }

}

+(NSString*) preferencesAsDescriptiveString{

    //Dump the preferences into a string
    
    NSMutableString* preferenceString = [[NSMutableString alloc] init];
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    for(NSString* file in [NSArray arrayWithObjects:@"Root", @"Dropbox", nil]){
        IASKSettingsReader* reader = [[IASKSettingsReader alloc] initWithFile:file];
        for(NSInteger section =0 ; section < [reader numberOfSections]; section++){
            for(NSInteger row =0 ; row < [reader numberOfRowsForSection:section]; row++){
                IASKSpecifier* prefItem = [reader specifierForIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
                if(! [prefItem.type isEqualToString:@"PSChildPaneSpecifier"]){
                    NSObject* valueObject = [defaults objectForKey:prefItem.key];
                    NSString* valueTitle= [prefItem titleForCurrentValue:valueObject];
                    NSString* title = [prefItem title];
                    if([@"" isEqualToString:valueTitle]){
                        [preferenceString appendFormat:@"%@: %@\n",title, valueObject];
                    }
                    else{
                        [preferenceString appendFormat:@"%@: %@\n",title, valueTitle];
                    }
                }
            }
            
        }
    }
    return preferenceString;

}

+(void) checkAndProcessApplicationResetPreferences{
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    if([defaults boolForKey:@"resetusername"]){
        DDLogWarn(@"Reseting username");
        [self resetUserCredentials];
        
        //Also reset the data

        [ZPDatabase resetDatabase];
        [ZPFileCacheManager performSelectorInBackground:@selector(purgeAllAttachmentFilesFromCache) withObject:NULL];
        
        [defaults removeObjectForKey:@"resetusername"];
        [defaults removeObjectForKey:@"resetdata"];

    }
    
    else if([defaults boolForKey:@"resetdata"]){
        DDLogWarn(@"Reseting itemdata and deleting cached attachments");
        [defaults removeObjectForKey:@"resetdata"];
        [ZPDatabase resetDatabase];
        [ZPFileCacheManager performSelectorInBackground:@selector(purgeAllAttachmentFilesFromCache) withObject:NULL];
    }
}
+(void) resetUserCredentials{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"username"];
    self.username = NULL;
    [defaults removeObjectForKey:@"userID"];
    self.userID = NULL;
    [defaults removeObjectForKey:@"OAuthKey"];
    self.OAuthKey = NULL;

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
+(NSInteger) maxCacheSize{
    return _maxCacheSize;
}

+(BOOL) cacheMetadataAllLibraries{
    return _metadataCacheLevel >=3;
}

+(BOOL) cacheMetadataActiveLibrary{
    return _metadataCacheLevel >=2;
}
+(BOOL) cacheMetadataActiveCollection{
    return _metadataCacheLevel >=1;
}

+(BOOL) cacheAttachmentsAllLibraries{
    return _attachmentsCacheLevel >=4;
}

+(BOOL) cacheAttachmentsActiveLibrary{
    return _attachmentsCacheLevel >=3;
}
+(BOOL) cacheAttachmentsActiveCollection{
    return _attachmentsCacheLevel >=2;
}
+(BOOL) cacheAttachmentsActiveItem{
    return _attachmentsCacheLevel >=1;
}

+(BOOL) useCache{
    return (_mode != 0);
}

+(BOOL) online{
    return (_mode != 2);
}

+(void) setOnline:(BOOL)online{
    if(online) _mode = 1;
    else _mode = 2;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInt:_mode] forKey:@"mode"];
}

+(BOOL) reportErrors{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"errorreports"];
}

+(BOOL) useDropbox{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults objectForKey:@"filechannel"] isEqualToString:@"dropbox"];
}

+(BOOL) dropboxHasFullControl{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"dropboxfullcontrol"];
    
}
+(NSString*) dropboxPath{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [[[defaults stringForKey:@"dropboxpath"] 
             stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
            stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\"]];
}
+(void) setDropboxPath:(NSString*)path{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:path forKey:@"dropboxpath"];
}

+(BOOL) useCustomFilenamesWithDropbox{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"dropboxusecustomfilenames"];
}

+(NSString*) customFilenamePatternForDropbox{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults stringForKey:@"dropboxfilenamepattern"];
}
+(NSString*) customSubfolderPatternForDropbox{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults stringForKey:@"dropboxsubfolderpattern"];
}

+(NSString*) customPatentFilenamePatternForDropbox{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults stringForKey:@"dropboxfilenamepatternpatents"];
}

+(BOOL) replaceBlanksInDropboxFilenames{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"dropboxreplaceblanks"];
}
+(BOOL) removeDiacriticsInDropboxFilenames{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"dropboxremovediacritics"];
}

+(BOOL) truncateTitlesInDropboxFilenames{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"dropboxtruncatetitle"];
}

+(NSInteger) maxTitleLengthInDropboxFilenames{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults integerForKey:@"dropboxtitlelenght"];
}

+(NSInteger) maxNumberOfAuthorsInDropboxFilenames{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults integerForKey:@"dropboxnumberofauthor"];
}

+(NSString*) authorSuffixInDropboxFilenames{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults stringForKey:@"dropboxauthorsuffix"];
}
+(BOOL) downloadLinkedFilesWithDropbox{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"dropboxdownloadlinkedfiles"];
}
+(BOOL) useWebDAV{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults objectForKey:@"filechannel"] isEqualToString:@"webdavzotero"];
}
+(void) setUseWebDAV:(BOOL) value{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if(value) [defaults setObject:@"webdavzotero" forKey:@"filechannel"];
    else [defaults setObject:@"zotero" forKey:@"filechannel"];
}

+(NSString*) webDAVURL{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* ret = [[defaults objectForKey:@"webdavurl"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    //String trailing slash
    if([ret hasSuffix:@"/"]){
        ret = [ret substringToIndex:[ret length] - 1];
    }

    return ret;
}

+(NSString*) username{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"username"];
}
+(void) setUsername: (NSString*) value {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:value forKey:@"username"];
}


+(NSString*) userID{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if([defaults boolForKey:@"debugauthenticationoverride"]){
        return [defaults objectForKey:@"debuguserideoverride"];
    }
    else{
        return [defaults objectForKey:@"userID"];
    }
}
+(void) setUserID: (NSString*) value {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:value forKey:@"userID"];
}

+(NSString*) OAuthKey{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if([defaults boolForKey:@"debugauthenticationoverride"]){
        return [defaults objectForKey:@"debugapikeyeoverride"];
    }
    else{
        return [defaults objectForKey:@"OAuthKey"];
    }
}
+(void) setOAuthKey:(NSString*) value {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:value forKey:@"OAuthKey"];
}

+(NSString*) currentCacheSize{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"cachesizecurrent"];
}
+(void) setCurrentCacheSize:(NSString*) value {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:value forKey:@"cachesizecurrent"];
}

//Advanced settings

+(BOOL) includeDatabaseWithSupportRequest{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"supportincludedatabase"];
}

+(BOOL) includeFileListWithSupportRequest{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"supportincludefilelisting"];
}

+(BOOL) recursiveCollections{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"recursivecollections"];
}

+(BOOL) layeredCollectionsNavigation{
    //For now this is always enabled
    return TRUE;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"layeredcollectionsnavigation"];
}

+(BOOL) unifiedCollectionsNavigation{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) return FALSE;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"unifiedcollectionsnavigation"];
}
+(BOOL) debugCitationParser{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"debugcitationparser"];
}
+(BOOL) debugFileUploads{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"debugfileuploads"];
}

+(BOOL) addIdentifiersToAPIRequests{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"debugserverrequests"];
}

+(NSString*) favoritesCollectionTitle{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* value = [defaults stringForKey:@"favoritescollectiontitle"];
    if(value == NULL || [value isEqualToString:@""]){
        value = @"ZotPad favourites";
    }
    return value;
    
}

+(BOOL) prioritizePDFsInAttachmentLists{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"prioritizepdfs"];
}

+(BOOL) displayItemKeys
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"displayitemkeys"];
}

@end
