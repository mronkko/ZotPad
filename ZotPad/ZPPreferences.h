//
//  ZPPreferences.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPPreferences : NSObject{
    NSInteger _metadataCacheLevel;
    NSInteger _attachmentsCacheLevel;
    NSInteger _mode;
    NSInteger _maxCacheSize;
}

@property (retain) NSString* OAuthKey;
@property (retain) NSString* userID;
@property (retain) NSString* username;
@property (retain) NSString* currentCacheSize;

@property BOOL online;

@property BOOL useWebDAV;

+(ZPPreferences*) instance;
-(BOOL) cacheMetadataAllLibraries;
-(BOOL) cacheMetadataActiveLibrary;
-(BOOL) cacheMetadataActiveCollection;

-(BOOL) cacheAttachmentsAllLibraries;
-(BOOL) cacheAttachmentsActiveLibrary;
-(BOOL) cacheAttachmentsActiveCollection;
-(BOOL) cacheAttachmentsActiveItem;

-(BOOL) useCache;

//Dropbox spesific settings
-(BOOL) useDropbox;
-(BOOL) dropboxHasFullControl;
-(void) setDropboxPath:(NSString*) path;
-(NSString*) dropboxPath;
-(BOOL) useCustomFilenamesWithDropbox;
-(NSString*) customFilenamePatternForDropbox;
-(NSString*) customPatentFilenamePatternForDropbox;
-(NSString*) customSubfolderPatternForDropbox;
-(BOOL) replaceBlanksInDropboxFilenames;
-(BOOL) removeDiacriticsInDropboxFilenames;
-(BOOL) truncateTitlesInDropboxFilenames;
-(NSInteger) maxTitleLengthInDropboxFilenames;
-(NSInteger) maxNumberOfAuthorsInDropboxFilenames;
-(NSString*) authorSuffixInDropboxFilenames;

-(BOOL) reportErrors;

-(NSString*) webDAVURL;
-(NSInteger) maxCacheSize;

-(void) resetUserCredentials;

-(void) reload;
-(void) checkAndProcessApplicationResetPreferences;

@end
