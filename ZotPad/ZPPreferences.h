//
//  ZPPreferences.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPPreferences : NSObject{
}

+(NSString*) OAuthKey;
+(void) setOAuthKey:(NSString*)key;

+(NSString*) userID;
+(void) setUserID:(NSString*)userID;

+(void) setUsername:(NSString*)userName;

+(void) setCurrentCacheSize:(NSString*)cacheSize;

+(BOOL) online;
+(void) setOnline:(BOOL)online;


+(BOOL) useWebDAV;
+(void) setUseWebDAV:(BOOL)useWebDAV;

+(BOOL) cacheMetadataAllLibraries;
+(BOOL) cacheMetadataActiveLibrary;
+(BOOL) cacheMetadataActiveCollection;

+(BOOL) cacheAttachmentsAllLibraries;
+(BOOL) cacheAttachmentsActiveLibrary;
+(BOOL) cacheAttachmentsActiveCollection;
+(BOOL) cacheAttachmentsActiveItem;

+(BOOL) useCache;
+(NSString*) webDAVURL;
+(NSInteger) maxCacheSize;

+(void) resetUserCredentials;

+(void) reload;
+(void) checkAndProcessApplicationResetPreferences;

//Dropbox spesific settings
+(BOOL) useDropbox;
+(BOOL) dropboxHasFullControl;
+(void) setDropboxPath:(NSString*) path;
+(NSString*) dropboxPath;
+(BOOL) useCustomFilenamesWithDropbox;
+(NSString*) customFilenamePatternForDropbox;
+(NSString*) customPatentFilenamePatternForDropbox;
+(NSString*) customSubfolderPatternForDropbox;
+(BOOL) replaceBlanksInDropboxFilenames;
+(BOOL) removeDiacriticsInDropboxFilenames;
+(BOOL) truncateTitlesInDropboxFilenames;
+(NSInteger) maxTitleLengthInDropboxFilenames;
+(NSInteger) maxNumberOfAuthorsInDropboxFilenames;
+(NSString*) authorSuffixInDropboxFilenames;
+(BOOL) downloadLinkedFilesWithDropbox;
+(BOOL) reportErrors;

//Advanced settings

+(BOOL) includeDatabaseWithSupportRequest;
+(BOOL) includeFileListWithSupportRequest;
+(BOOL) recursiveCollections;
+(BOOL) debugCitationParser;
+(BOOL) layeredCollectionsNavigation;
+(BOOL) unifiedCollectionsNavigation;
+(BOOL) addIdentifiersToAPIRequests;



@end
