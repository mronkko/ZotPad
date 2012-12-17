
//
//  ZPZoteroItem.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/23/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "CSLFormatter.h"

@interface ZPZoteroItem()

-(void) _configureFieldsDependingOnFullCitation;

@end

@implementation ZPZoteroItem

@synthesize numTags,dateAdded,etag;

//TODO: Consider what happens when the cache is purged. This may result in duplicate objects with the same key.

static NSCache* _objectCache = NULL;
static CSLFormatter* _cslFormatter = NULL;

+(void) initialize{
    if(_cslFormatter == NULL){
        _cslFormatter = [[CSLFormatter alloc] initWithCSLFile:[[NSBundle mainBundle] pathForResource: @"apa" ofType: @"csl"]
                                                            localeFile:[[NSBundle mainBundle] pathForResource: @"locales-en-US" ofType: @"xml"]
                                                          fieldMapFile:[[NSBundle mainBundle] pathForResource: @"typeMap" ofType: @"xml"]];
    }
    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];

}

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

    
    ZPZoteroItem* obj= [_objectCache objectForKey:key];
    
    
    if(obj==NULL){

        NSDictionary* attributes = [ZPDatabase attributesForItemWithKey:(NSString*)key];
        
        obj = [self itemWithDictionary:attributes];
    }


    return obj;
}

-(void) _configureFieldsDependingOnFullCitation{

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
    
    //It is possible that we do not have fields if the database is not fully up to date.
    
    if([fields count]>0){
        
        @try {
            _fullCitation = [_cslFormatter formatBibliographyItemUsingVariables:fields storeMacrosInDictionary:macroDict];
        }
        @catch (NSException * e) {
            DDLogError(@"CSL formatting exception. Item %@ could not be formatted. %@",self.key,e);

            //Fill in some values to prevent a crash
            _fullCitation = @"CSL formatting resulted in an error";
            _creatorSummary = @"";
            _publicationDetails = @"";
        }
        
        NSString* authorMacro = [macroDict objectForKey:@"author"];
        NSString* dateMacro = [[macroDict objectForKey:@"issued"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] ;
        
        if(authorMacro == NULL){
            if([dateMacro isEqualToString:@"(n.d.)"]){
                _creatorSummary = @"";
            }
            else{
                _creatorSummary = dateMacro;
            }
        }
        else{
            _creatorSummary = [[NSString stringWithFormat:@"%@. %@",authorMacro, dateMacro] stringByReplacingOccurrencesOfString:@".." withString:@"."];
        }

        NSString* issued = [macroDict objectForKey:@"issued"];
        if(issued == NULL || issued.length <= 3){
            DDLogError(@"CSL formatting error. The item with key %@ has issued macro %@",self.key,issued);
        }
        else{
            _year = [[issued substringWithRange:NSMakeRange(2, [issued length]-3)] integerValue];
        }
        
        
        // Get the rest of the citation based on the APA style
        /*
         <layout>
         <group suffix=".">
         <group delimiter=". ">
         <text macro="author"/>
         <text macro="issued"/>
         <text macro="title" prefix=" "/>
         <text macro="container"/>
         </group>
         <text macro="locators"/>
         <group delimiter=", " prefix=". ">
         <text macro="event"/>
         <text macro="publisher"/>
         </group>
         </group>
         <text macro="access" prefix=" "/>
         </layout>
         */
        NSString* container = [macroDict objectForKey:@"container"];
        NSString* locators = [macroDict objectForKey:@"locators"];
        NSString* event = [macroDict objectForKey:@"event"];
        NSString* publisher = [macroDict objectForKey:@"publisher"];
        NSString* access = [macroDict objectForKey:@"access"];
        
        if(container!=NULL && [container length] ==0 ) container = NULL;
        if(locators!=NULL && [locators length] ==0 ) locators = NULL;
        if(event!=NULL && [event length] ==0 ) event = NULL;
        if(publisher!=NULL && [publisher length] ==0 ) publisher = NULL;
        if(access!=NULL && [access length] ==0 ) access = NULL;
        
        NSMutableString* temp =[[NSMutableString alloc] init];
        if(container != NULL){
            [temp appendString:container];
        }
        if(locators!=NULL){
            [temp appendString:locators];
        }
        if(event!=NULL || publisher != NULL){
            if([temp length]>0)[temp appendString:@". "];
            if(event!=NULL){
                [temp appendString:event];
                if(publisher!=NULL){
                    [temp appendString:@", "];
                    [temp appendString:publisher];
                }
            }
            else{
                [temp appendString:publisher];
            }
        }
        [temp appendString:@"."];
        if(access != NULL){
            [temp appendString:access];
        }
        
        _publicationDetails = temp;
    }
    else{
        // Use blank values so that the App would not crash
        _fullCitation = self.title;
        _creatorSummary = @"";
        _year = 0;
        _publicationDetails =@"";
    
        DDLogError(@"CSL formatting error. The item with key %@ does not have any fields",self.key);
    }
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
        [ZPDatabase addNotesToItem:self];
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
