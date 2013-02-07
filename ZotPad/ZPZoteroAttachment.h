//
//  ZPZoteroAttachment.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroDataObjectWithNote.h"


#import <QuickLook/QuickLook.h>


extern NSInteger const LINK_MODE_IMPORTED_FILE;
extern NSInteger const LINK_MODE_IMPORTED_URL;
extern NSInteger const LINK_MODE_LINKED_FILE;
extern NSInteger const LINK_MODE_LINKED_URL;

extern NSInteger const VERSION_SOURCE_DROPBOX;
extern NSInteger const VERSION_SOURCE_ZOTERO;
extern NSInteger const VERSION_SOURCE_WEBDAV;

@interface ZPZoteroAttachment : ZPZoteroDataObject <QLPreviewItem, ZPZoteroDataObjectWithNote>{
    NSInteger _linkMode;
}

@property (retain) NSString* note;
@property (retain) NSString* contentType;
@property (assign) NSInteger linkMode;
@property (assign) BOOL existsOnZoteroServer;
@property (assign) NSInteger attachmentSize;
@property (retain) NSString* lastViewed;
@property (retain) NSString* url;
@property (retain) NSString* filename;
@property (retain) NSString* charset;
@property (retain) NSString* itemKey;
@property (retain) NSString* accessDate;
@property (assign) long long mtime;

// Needed for versioning

// This is the version identifier from Zotero server. We need this as well as versionIdentifier_server because the actual file can also come from Dropbox
@property (retain) NSString* md5;

@property (assign) NSInteger versionSource;
@property (retain) NSString* versionIdentifier_server;
@property (retain) NSString* versionIdentifier_local;

+(ZPZoteroAttachment*) attachmentWithKey:(NSString*) key;
+(ZPZoteroAttachment*) attachmentWithDictionary:(NSDictionary*) fields;

- (NSString*) fileSystemPath;
- (NSString*) fileSystemPath_modified;
- (NSString*) fileSystemPath_original;
- (BOOL) fileExists;
-(BOOL) fileExists_original;
-(BOOL) fileExists_modified;

-(NSString*) filenameZoteroBase64Encoded;

// returns an object based on file system path
+(ZPZoteroAttachment*) dataObjectForAttachedFile:(NSString*) filename;


//TODO: Refactor these away. This is a quick an dirty way to clean local edit state
-(BOOL)locallyAdded;
-(BOOL)locallyModified;
-(BOOL)locallyDeleted;

// Helper functions
+(NSString*) md5ForFileAtPath:(NSString*)path;
+(NSString*) zoteroBase64Encode:(NSString*)filename;
+(NSString*) zoteroBase64Decode:(NSString*)filename;
-(void) logFileRevisions;

@end
