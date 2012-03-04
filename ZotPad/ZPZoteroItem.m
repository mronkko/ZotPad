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

@synthesize fullCitation = _fullCitation;
@synthesize numTags = _numTags;

static NSCache* _objectCache = NULL;

+(BOOL) existsInCache:(NSString*) key{
    ZPZoteroItem* obj= [_objectCache objectForKey:key];
    
    return ! (obj == nil);
        
}

-(id) init{
    self = [super init];
    _isStandaloneAttachment = FALSE;
    _isStandaloneNote = FALSE;
    return self;
}

+(id) dataObjectWithDictionary:(NSDictionary *)fields{
    
    NSString* key = [fields objectForKey:@"itemKey"];
    
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
        
        [obj configureWithDictionary:fields];
        [_objectCache setObject:obj  forKey:key];
    }
    else [obj configureWithDictionary:fields];

    return obj;
}

+(id) dataObjectWithKey:(NSObject*) key{
    
    if(key == NULL)
        [NSException raise:@"Key is null" format:@"ZPZoteroItem cannot be instantiated with NULL key"];
    if([key isEqual:@""])
        [NSException raise:@"Key is empty" format:@"ZPZoteroItem cannot be instantiated with empty key"];

    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroItem* obj= [_objectCache objectForKey:key];
    
    //It is possible that subclasses of this class have already been instantiated with this key, so we need to reinstantiate the object
    
    if(obj==NULL || ! [obj isKindOfClass:[self class]]){
        obj= [[self alloc] init];
        obj->_key=(NSString*)key;
        
        //Retrieve data for this item from DB
        [[ZPDatabase instance] addAttributesToItem:obj] ;

        
        [_objectCache setObject:obj  forKey:key];
    }
    return obj;
}

+(void) dropCache{
    [_objectCache removeAllObjects];
}

-(NSString*) publicationDetails{
    
    //If there are no authors.
    if([[self creators] count]==0){
        //Anything after the first closing parenthesis is publication details
        NSRange range = [_fullCitation rangeOfString:@")"];
        return [_fullCitation substringFromIndex:(range.location+1)];
    }
    else{
        
        NSRange range = [_fullCitation rangeOfString:self.title];
        
        //Sometimes the title can contain characters that are not formatted properly by the CSL parser on Zotero server. In this case we will just 
        //give up parsing it

        if(range.location!=NSNotFound){
            //Anything after the first period after the title is publication details
            NSInteger index = range.location+range.length;
            range = [_fullCitation rangeOfString:@"." options:0 range:NSMakeRange(index, ([_fullCitation length]-index))];
            index = (range.location+2);
            if(index<[_fullCitation length]){
                NSString* publicationTitle = [_fullCitation substringFromIndex:index];
                return [publicationTitle stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"., "]];
            }
        }
    }    

    return @"";
}

-(NSString*) creatorSummary{
    
    //Anything before the first parenthesis in an APA citation is author unless it is in italic
    
    NSString* authors = (NSString*)[[_fullCitation componentsSeparatedByString:@" ("] objectAtIndex:0];
    
    if([authors rangeOfString:@"<i>"].location == NSNotFound){
        return authors;
    }
    else return @"";
        
}

-(NSInteger*) year{
    NSString* value = [[self fields] objectForKey:@"date"];
    return [value intValue]; 
}

-(NSString*) itemType{
    return [[self fields] objectForKey:@"itemType"];
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

    //Remove empty fields. There is no need to store these in the DB or memory because they can be determined from item template
    
    NSEnumerator* e = [fields keyEnumerator];
    NSMutableDictionary* newFields = [NSMutableDictionary dictionary];
    NSString* key;
    while(key = [e nextObject]){
        NSString* value = [fields objectForKey:key];
        if(![value isEqual:@""]){
            [newFields setObject:value forKey:key];
        }
    }
    
    _fields = newFields;
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


-(NSArray*) collections{
    if(_collections == NULL){
        _collections = [[ZPDatabase instance] collectionsForItem:self];
    }
    return _collections;
}

-(NSString *) itemKey{
    return [self key];
}

-(NSString *) cacheTimestamp{
    NSString* ts = [super cacheTimestamp];
    if(ts == NULL) return [super serverTimestamp];
    else return ts;
}

@end
