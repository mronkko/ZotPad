//
//  ZPZoteroItem.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroItem.h"
#import "ZPZoteroAttachment.h"
#import "ZPDatabase.h"

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

+(id) retrieveOrInitializeWithKey:(NSString*) key{
    
    if(key == NULL)
        [NSException raise:@"Key is null" format:@"ZPZoteroItem cannot be instantiated with NULL key"];
    if([key isEqualToString:@""])
        [NSException raise:@"Key is empty" format:@"ZPZoteroItem cannot be instantiated with empty key"];

    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroItem* obj= [_objectCache objectForKey:key];
    
    //It is possible that subclasses of this class have already been instantiated with this key, so we need to reinstantiate the object
    
    if(obj==NULL || ! [obj isKindOfClass:[self class]]){
        obj= [[self alloc] init];
        obj->_key=key;
        obj->_needsToBeWrittenToCache = FALSE;
        
        //Retrieve data for this item from DB
        [[ZPDatabase instance] addBasicToItem:obj] ;

        
        [_objectCache setObject:obj  forKey:key];
    }
    return obj;
}

-(NSString*)key{
    return _key;
}

- (NSArray*) creators{
    if(_creators == NULL){
        [[ZPDatabase instance] addCreatorsToItem:self];
        if(_creators ==NULL) [NSException raise:@"Creators cannot be null" format:@"Reading an item (%@) from database resulted in null creators. "];
    }
    return _creators;
}
- (void) setCreators:(NSArray*)creators{
    _creators = creators;
}

- (NSArray*) attachments{
    if(_attachments == NULL){
        [[ZPDatabase instance] addAttachmentsToItem:self];
    }
    return _attachments;
}
- (void) setAttachments:(NSArray *)attachments{
    _attachments = attachments;
}

- (NSDictionary*) fields{
    if(_fields == NULL){
        [[ZPDatabase instance] addFieldsToItem:self];
    }
    return  _fields;
}

- (void) setFields:(NSDictionary*)fields{
    _fields = fields;
}

- (NSArray*) notes{
    if(_notes == NULL){
        //TODO: Implement notes
        //[[ZPDatabase instance] addNotesItem:self];
    }
    return _notes;
}
- (void) setNotes:(NSArray*)notes{
    _notes = notes;
}

/*

-(ZPZoteroAttachment*) firstExistingAttachment{

    for(ZPZoteroAttachment* attachment in _attachments){
        if([attachment fileExists]){
            return attachment;
        }
    }
    return NULL;
}
*/
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
