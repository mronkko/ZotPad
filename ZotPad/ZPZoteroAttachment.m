//
//  ZPZoteroAttachment.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//


// TODO: Implement linked files or at least some kind of info that they are not supported

#import "ZPZoteroAttachment.h"

@implementation ZPZoteroAttachment


@synthesize attachmentURL = _attachmentURL;
@synthesize attachmentType = _attachmentType;
@synthesize attachmentTitle = _attachmentTitle;
@synthesize attachmentLength = _attachmentLength;
@synthesize lastViewed;

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
    
    if(_attachmentTitle == NULL) return NULL;
    
    NSRange lastPeriod = [_attachmentTitle rangeOfString:@"." options:NSBackwardsSearch];
    
    NSString* path;
    if(lastPeriod.location == NSNotFound) path = [_attachmentTitle stringByAppendingFormat:@"_",_key];
    else path = [_attachmentTitle stringByReplacingCharactersInRange:lastPeriod
                                                                    withString:[NSString stringWithFormat:@"_%@.",_key]];
    return  [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:path];

}

- (NSArray*) creators{
    return [NSArray array];
}
- (NSDictionary*) fields{
    return [NSDictionary dictionary];
}

-(NSString*) itemType{
    return @"attachment";
}

- (NSArray*) attachments{
    
    return [NSArray arrayWithObject:self];
}

- (void) setAttachments:(NSArray *)attachments{
}

//If an attachment is updated, delete the old attachment file
- (void) setServerTimestamp:(NSString*)timestamp{
    [super setServerTimestamp:timestamp];
    if(![_serverTimestamp isEqual:_cacheTimestamp] && [self fileExists]){
        NSError* error;
        [[NSFileManager defaultManager] removeItemAtPath: [self fileSystemPath] error:&error];   
    }
    
}

-(BOOL) fileExists{
    NSString* fsPath = [self fileSystemPath];
    if(fsPath == NULL)
        return false;
    else
        return ([[NSFileManager defaultManager] fileExistsAtPath:fsPath]);
}
@end

