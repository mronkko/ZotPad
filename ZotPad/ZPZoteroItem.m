//
//  ZPZoteroItem.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroItem.h"
#import "ZPZoteroAttachment.h"

@implementation ZPZoteroItem

@synthesize title = _title;
@synthesize fullCitation = _fullCitation;
@synthesize creatorSummary = _creatorSummary;
@synthesize year = _year;
@synthesize libraryID = _libraryID;
@synthesize hasChildren = _hasChildren;
@synthesize publishedIn = _publishedIn;
@synthesize itemType = _itemType;
@synthesize numChildren = _numChildren;
@synthesize numTags = _numTags;

@synthesize creators = _creators;
@synthesize attachments = _attachments;
@synthesize notes = _notes;
@synthesize fields = _fields;

//Timestamp uses a custom setter because it is used to determine if the item needs to be written in cache

-(NSString*) lastTimestamp{
    return _lastTimestamp;
} 

/*
 
 */

-(void) setLastTimestamp:(NSString*) value{
    if(! [value isEqualToString:_lastTimestamp]) _needsToBeWrittenToCache = TRUE;
    _lastTimestamp = value;
} 

-(BOOL) needsToBeWrittenToCache{
    return _needsToBeWrittenToCache;
}

-(void) clearNeedsToBeWrittenToCache{
    _needsToBeWrittenToCache = FALSE;
}

static NSCache* _objectCache = NULL;

+(BOOL) existsInCache:(NSString*) key{
    ZPZoteroItem* obj= [_objectCache objectForKey:key];
    
    return ! (obj == nil);
        
}

+(ZPZoteroItem*) ZPZoteroItemWithKey:(NSString*) key{
    
    if(key == NULL)
        [NSException raise:@"Key is null" format:@"ZPZoteroItem cannot be instantiated with NULL key"];

    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroItem* obj= [_objectCache objectForKey:key];
    
    if(obj==NULL){
        obj= [[ZPZoteroItem alloc] init];
        obj->_key=key;
        obj->_needsToBeWrittenToCache = FALSE;
        [_objectCache setObject:obj  forKey:key];
    }
    return obj;
}

-(NSString*)key{
    return _key;
}

-(ZPZoteroAttachment*) firstExistingAttachment{

    for(ZPZoteroAttachment* attachment in _attachments){
        if([attachment fileExists]){
            return attachment;
        }
    }
    return NULL;
}

-(NSArray*) allExistingAttachments{
    NSMutableArray* returnArray = [NSMutableArray arrayWithCapacity:[_attachments count]];

    for(ZPZoteroAttachment* attachment in _attachments){
        if([attachment fileExists]){
            [returnArray addObject:attachment];
        }
    }
    
    return returnArray;
}

- (BOOL)isEqual:(id)anObject{
    if([anObject isKindOfClass:[self class]]){
        return [[(ZPZoteroItem*) anObject key] isEqualToString: _key];
    }
    else return FALSE;
}

@end
