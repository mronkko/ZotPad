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

-(NSString*) defaultApplicationForContentType:(NSString*) type;
-(void) setDefaultApplication:(NSString*) application forContentType:(NSString*) type;

-(BOOL) useCache;
-(BOOL) useDropbox;
-(BOOL) reportErrors;

-(NSString*) webDAVURL;
-(NSInteger) maxCacheSize;

-(void) resetUserCredentials;

-(void) reload;
-(void) checkAndProcessApplicationResetPreferences;

@end
