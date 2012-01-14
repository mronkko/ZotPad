//
//  ZPZoteroAttachment.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroItem.h"

@interface ZPZoteroAttachment : ZPZoteroItem{
    NSString* _parentItemKey;
    
    
    NSString* _attachmentURL;
    NSString* _attachmentType;
    NSString* _attachmentTitle;
    NSInteger _attachmentLength;
}

@property (retain) NSString* parentItemKey;
@property (retain) NSString* attachmentURL;
@property (retain) NSString* attachmentType;
@property (retain) NSString* attachmentTitle;
@property (assign) NSInteger attachmentLength;


// An alias for setParentItemKey
- (void) setParentKey:(NSString*)key;
- (NSString*) fileSystemPath;
- (BOOL) fileExists;
+(id) retrieveOrInitializeWithKey:(NSString*) key;

@end
