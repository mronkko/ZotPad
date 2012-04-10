//
//  ZPZoteroAttachment.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroItem.h"


extern NSInteger const LINK_MODE_IMPORTED_FILE;
extern NSInteger const LINK_MODE_IMPORTED_URL;
extern NSInteger const LINK_MODE_LINKED_FILE;
extern NSInteger const LINK_MODE_LINKED_URL;

@interface ZPZoteroAttachment : ZPZoteroItem{
    NSString* _parentItemKey;
}

@property (retain) NSString* parentItemKey;
@property (retain) NSString* contentType;
@property (retain) NSString* linkMode;
@property (retain) NSNumber* existsOnZoteroServer;
@property (retain) NSNumber* attachmentSize;
@property (retain) NSString* lastViewed;
@property (retain) NSString* URL;
@property (retain) NSString* filename;
	
// An alias for setParentItemKey
- (void) setParentKey:(NSString*)key;
- (NSString*) fileSystemPath;
- (BOOL) fileExists;

// returns an object based on file system path
+(ZPZoteroAttachment*) dataObjectForAttachedFile:(NSString*) filename;

@end
