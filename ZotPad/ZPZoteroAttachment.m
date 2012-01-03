//
//  ZPZoteroAttachment.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroAttachment.h"

@implementation ZPZoteroAttachment

@synthesize lastTimestamp = _lastTimestamp;
@synthesize parentItemKey = _parentItemKey;
@synthesize attachmentURL = _attachmentURL;
@synthesize attachmentType = _attachmentType;
@synthesize attachmentTitle = _attachmentTitle;
@synthesize attachmentLength = _attachmentLength;

static NSCache* _objectCache = NULL;

+(ZPZoteroAttachment*) ZPZoteroAttachmentWithKey:(NSString*) key{
    
    if(key == NULL)
        [NSException raise:@"Key is null" format:@"ZPZoteroAttachment cannot be instantiated with NULL key"];
    
    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroAttachment* obj= [_objectCache objectForKey:key];
    
    if(obj==NULL){
        obj= [[ZPZoteroAttachment alloc] init];
        obj->_key=key;
        [_objectCache setObject:obj  forKey:key];
    }
    return obj;
}

-(NSString*)key{
    return _key;
}

// An alias for setParentCollectionKey
- (void) setParentKey:(NSString*)key{
    [self setParentItemKey:key];    
}

- (NSString*) fileSystemPath{
    
    NSRange lastPeriod = [_attachmentTitle rangeOfString:@"." options:NSBackwardsSearch];
    NSString *path = [_attachmentTitle stringByReplacingCharactersInRange:lastPeriod
                                                                    withString:[NSString stringWithFormat:@".%@.",_key]];
    return  [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:path];

}

-(BOOL) fileExists{
    return ([[NSFileManager defaultManager] fileExistsAtPath:[self fileSystemPath]]);
}
@end
