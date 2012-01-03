//
//  ZPZoteroAttachment.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPZoteroAttachment : NSObject{
    NSString* _key;
    NSString* _lastTimestamp;
    NSString* _parentItemKey;
    
    
    NSString* _attachmentURL;
    NSString* _attachmentType;
    NSString* _attachmentTitle;
    NSInteger _attachmentLength;
}

@property (retain) NSString* lastTimestamp;
@property (retain) NSString* parentItemKey;
@property (retain) NSString* attachmentURL;
@property (retain) NSString* attachmentType;
@property (retain) NSString* attachmentTitle;
@property (assign) NSInteger attachmentLength;


+(ZPZoteroAttachment*) ZPZoteroAttachmentWithKey:(NSString*) key;
-(NSString*)key;

// An alias for setParentItemKey
- (void) setParentKey:(NSString*)key;
- (NSString*) fileSystemPath;
- (BOOL) fileExists;

@end
