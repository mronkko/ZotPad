//
//  ZPZoteroItem.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroItem.h"

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
@synthesize lastTimestamp = _lastTimestamp;

@synthesize creators = _creators;
@synthesize attachments = _attachments;
@synthesize notes = _notes;
@synthesize fields = _fields;


static NSCache* _objectCache = NULL;

+(ZPZoteroItem*) ZPZoteroItemWithKey:(NSString*) key{
    
    if(key == NULL)
        [NSException raise:@"Key is null" format:@"ZPZoteroItem cannot be instantiated with NULL key"];

    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroItem* obj= [_objectCache objectForKey:key];
    
    if(obj==NULL){
        obj= [[ZPZoteroItem alloc] init];
        obj->_key=key;
        [_objectCache setObject:obj  forKey:key];
    }
    return obj;
}

-(NSString*)key{
    return _key;
}


@end
