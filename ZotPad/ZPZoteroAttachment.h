//
//  ZPZoteroAttachment.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ZPZoteroItem.h"
#import <QuickLook/QuickLook.h>


extern NSInteger const LINK_MODE_IMPORTED_FILE;
extern NSInteger const LINK_MODE_IMPORTED_URL;
extern NSInteger const LINK_MODE_LINKED_FILE;
extern NSInteger const LINK_MODE_LINKED_URL;

extern NSInteger const VERSION_SOURCE_DROPBOX;
extern NSInteger const VERSION_SOURCE_ZOTERO;
extern NSInteger const VERSION_SOURCE_WEBDAV;

@interface ZPZoteroAttachment : ZPZoteroItem <QLPreviewItem>{
    __strong NSString* _parentItemKey;
    __strong NSNumber* _linkMode;
    //TODO: Recycle content type strings
    __strong NSString* _contentType;    
}

@property (retain) NSString* parentItemKey;
@property (retain) NSString* contentType;
@property (retain) NSNumber* linkMode;
@property (retain) NSNumber* existsOnZoteroServer;
@property (retain) NSNumber* attachmentSize;
@property (retain) NSString* lastViewed;
@property (retain) NSString* url;
@property (retain) NSString* filename;
	
// Needed for versioning

@property (retain) NSNumber* versionSource;
@property (retain) NSString* versionIdentifier_receivedFromServer;
@property (retain) NSString* versionIdentifier_sentOut;
@property (retain) NSString* versionIdentifier_receivedLocally;

// An alias for setParentItemKey
- (void) setParentKey:(NSString*)key;
- (NSString*) fileSystemPath;
- (BOOL) fileExists;

// returns an object based on file system path
+(ZPZoteroAttachment*) dataObjectForAttachedFile:(NSString*) filename;

@end
