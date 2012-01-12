//
//  ZPZoteroAttachment.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroAttachment.h"

@implementation ZPZoteroAttachment


@synthesize attachmentURL = _attachmentURL;
@synthesize attachmentType = _attachmentType;
@synthesize attachmentTitle = _attachmentTitle;
@synthesize attachmentLength = _attachmentLength;


// An alias for setParentCollectionKey
- (void) setParentKey:(NSString*)key{
    [self setParentItemKey:key];    
}

- (void) setParentItemKey:(NSString*)key{
    _parentItemKey = key; 
}
- (NSString*) parentItemKey{
    if(_parentItemKey == NULL){
        return _key;
    }
    else{
        return _parentItemKey;
    }
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

