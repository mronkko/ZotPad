//
//  ZPZoteroItem.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/23/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"
#import "ZPDatabase.h"
#import "CSLFormatter.h"

@interface ZPZoteroItem()

-(void) _configureFieldsDependingOnFullCitation;

@end

@implementation ZPZoteroItem

@synthesize numTags,dateAdded,etag;

//TODO: Consider what happens when the cache is purged. This may result in duplicate objects with the same key.

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

+(ZPZoteroItem*) itemWithDictionary:(NSDictionary *)fields{
    
    NSString* key = [fields objectForKey:ZPKEY_ITEM_KEY];
    
    if(key == NULL || [key isEqual:@""])
        [NSException raise:@"Key is empty" format:@"ZPZoteroItem cannot be instantiated with empty key"];
        
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroItem* obj= [_objectCache objectForKey:key];
    
    if(obj==NULL){
        
        obj = [[ZPZoteroItem alloc] init];

        obj.key=key;
        
        [obj configureWithDictionary:fields];
        [_objectCache setObject:obj  forKey:key];
        
    }
    else [obj configureWithDictionary:fields];

    return obj;
}

+(ZPZoteroItem*) itemWithKey:(NSObject*) key{
    
    if(key == NULL || [key isEqual:@""])
        [NSException raise:@"Key is empty" format:@"ZPZoteroItem cannot be instantiated with empty key"];

    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroItem* obj= [_objectCache objectForKey:key];
    
    
    if(obj==NULL){

        NSDictionary* attributes = [ZPDatabase attributesForItemWithKey:(NSString*)key];
        
        obj = [self itemWithDictionary:attributes];
    }


    return obj;
}

-(void) _configureFieldsDependingOnFullCitation{
    CSLFormatter* cslFormatter = [[CSLFormatter alloc] initWithCSLFile:@"apa.csl" localeFile:@"locales-en-US.xml" fieldMapFile:@"typeMap.xml"];
    NSMutableDictionary* macroDict = [[NSMutableDictionary alloc] init];
    
    NSMutableDictionary* fields = [NSMutableDictionary dictionaryWithDictionary:self.fields];

    //Add creators
    
    //Get creators as separate variables
    for(NSDictionary* creator in self.creators){
        NSString* type = [creator objectForKey:@"creatorType"];
        
        NSMutableArray* creatorArray = [fields objectForKey:type];
        if(creatorArray == NULL){
            creatorArray = [[NSMutableArray alloc] init];
            [fields setObject:creatorArray forKey:type];
        }
        [creatorArray addObject:creator];
    }
    
    _fullCitation = [cslFormatter formatBibliographyItemUsingVariables:fields storeMacrosInDictionary:macroDict];
    
    _creatorSummary = [NSString stringWithFormat:@"%@. %@",[macroDict objectForKey:@"creator"],[macroDict objectForKey:@"issued"] ];
    _publicationDetails = [_fullCitation substringFromIndex:[_creatorSummary length]+2];
    _year = [[macroDict objectForKey:@"issued"] integerValue];
}

-(NSString*) fullCitation{
    if(_fullCitation == NULL) [self _configureFieldsDependingOnFullCitation];
    return _fullCitation;
}
-(NSString*) publicationDetails{
    if(_fullCitation == NULL) [self _configureFieldsDependingOnFullCitation];
    return _publicationDetails;
}

-(NSString*) creatorSummary{
    if(_fullCitation == NULL) [self _configureFieldsDependingOnFullCitation];
    return _creatorSummary;
}

-(NSInteger) year{
    if(_fullCitation == NULL) [self _configureFieldsDependingOnFullCitation];
    return _year;
}

-(void) setItemKey:(NSString *)itemKey{
    [super setKey:itemKey];
}
-(NSString*)itemKey{
    return [super key];
}

+(void) dropCache{
    [_objectCache removeAllObjects];
}


-(NSString*) itemType{
    return [[self fields] objectForKey:@"itemType"];
}

- (NSArray*) creators{
    if(_creators == NULL){
        [ZPDatabase addCreatorsToItem:self];
        if(_creators ==NULL) [NSException raise:@"Creators cannot be null" format:@"Reading an item (%@) from database resulted in null creators. ",self.key];
    }
    return _creators;
}

- (void) setCreators:(NSArray*)creators{
    _creators = creators;
}

- (NSArray*) attachments{
    
    if(_attachments == NULL){
        [ZPDatabase addAttachmentsToItem:self];
    }
    if(_attachments == NULL || ! [_attachments isKindOfClass:[NSArray class]]){
        [NSException raise:@"Internal consistency exception" format:@"Could not load attachments for item with key %@",self.key];
    }
    return _attachments;
}

-(void) setAttachments:(NSArray *)attachments{
    _attachments = attachments;
}

- (NSDictionary*) fields{
    if(_fields == NULL){
        [ZPDatabase addFieldsToItem:self];
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
            
            
            if([self respondsToSelector:NSSelectorFromString(key)]){
                [self setValue:value forKey:key];
            }

        }
    }
    
    _fields = newFields;
}

- (NSArray*) notes{
    
    if(_notes == NULL){
        //TODO: Implement notes
        //[ZPDatabase addNotesItem:self];
    }
    return _notes;
}
- (void) setNotes:(NSArray*)notes{

    _notes = notes;
}


-(NSArray*) collections{
    if(_collections == NULL){
        _collections = [ZPDatabase collectionsForItem:self];
    }
    return _collections;
}

- (NSString*) shortCitation{

    if(self.creatorSummary!=NULL && ! [self.creatorSummary isEqualToString:@""]){
        if(self.year!=0){
            return [NSString stringWithFormat:@"%@ (%i) %@",self.creatorSummary,self.year,self.title];
        }
        else{
            return [NSString stringWithFormat:@"%@ (no date) %@",self.creatorSummary,self.title];;
        }
    }
    else{
        return self.title;
    }
}

@end
