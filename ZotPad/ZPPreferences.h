//
//  ZPPreferences.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPPreferences : NSObject{
    NSInteger _metadataCacheLevel;
    NSInteger _attachmentsCacheLevel;
    NSInteger _mode;
    NSInteger _maxCacheSize;
}

+(ZPPreferences*) instance;
-(BOOL) cacheMetadataAllLibraries;
-(BOOL) cacheMetadataActiveLibrary;
-(BOOL) cacheMetadataActiveCollection;

-(BOOL) cacheAttachmentsAllLibraries;
-(BOOL) cacheAttachmentsActiveLibrary;
-(BOOL) cacheAttachmentsActiveCollection;
-(BOOL) cacheAttachmentsActiveItem;

-(BOOL) useCache;
-(BOOL) online;

-(NSInteger) maxCacheSize;

-(void) reload;

@end
