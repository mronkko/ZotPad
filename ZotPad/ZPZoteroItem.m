//
//  ZPZoteroItem.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/23/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"
#import "ZPDatabase.h"

@implementation ZPZoteroItem

@synthesize fullCitation, numTags,dateAdded,etag,jsonFromServer;
@synthesize attachments = _attachments;

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

+(id) dataObjectWithDictionary:(NSDictionary *)fields{
    
    NSString* key = [fields objectForKey:@"itemKey"];
    
    if(key == NULL || [key isEqual:@""])
        [NSException raise:@"Key is empty" format:@"ZPZoteroItem cannot be instantiated with empty key"];
        
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroItem* obj= [_objectCache objectForKey:key];
    
    if(obj==NULL){
        NSString* type = [fields objectForKey:@"itemType"];
        ZPZoteroItem* newObj;
        
        if([type isEqualToString:@"note"])
            newObj = [[ZPZoteroNote alloc] init];
        else if([type isEqualToString:@"attachment"])
            newObj = [[ZPZoteroAttachment alloc] init];
        else 
            newObj = [[ZPZoteroItem alloc] init];

        newObj.key=key;
        
        [newObj configureWithDictionary:fields];
        [_objectCache setObject:newObj  forKey:key];
        
        //TODO: refactor so that this "hack" is no longer needed to load the fields that are specific to attachments
        if([type isEqual:@"attachment"]){
            [[ZPDatabase instance] addAttachmentsToItem:newObj];
        }
        obj=newObj;
    }
    else [obj configureWithDictionary:fields];

    return obj;
}

+(id) dataObjectWithKey:(NSObject*) key{
    
    if(key == NULL || [key isEqual:@""])
        [NSException raise:@"Key is empty" format:@"ZPZoteroItem cannot be instantiated with empty key"];

    
    if(_objectCache == NULL) _objectCache = [[NSCache alloc] init];
    
    ZPZoteroItem* obj= [_objectCache objectForKey:key];
    
    
    if(obj==NULL){

        NSDictionary* attributes = [[ZPDatabase instance] attributesForItemWithKey:(NSString*)key];
        
        obj = (ZPZoteroItem*) [self dataObjectWithDictionary:attributes];
    }


    return obj;
}

+(void) dropCache{
    [_objectCache removeAllObjects];
}

-(NSString*) publicationDetails{
    
    if([self.fields count] == 0 || [self.itemType isEqualToString:@"note"] || [self.itemType isEqualToString:@"attachment"]){
        return @"";
    }
    
    //If there are no authors.
    if([[self creators] count]==0){
        //Anything after the first closing parenthesis is publication details
        NSRange range = [self.fullCitation rangeOfString:@")"];
        if(range.location != NSNotFound){
            return [[self.fullCitation substringFromIndex:(range.location+1)] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"., "]];   
        }
    }

    //If that did not give us publication details, return everything after the title
    
    NSString* title = self.title;
    NSRange range = [self.fullCitation rangeOfString:title];
    
    //Sometimes the title can contain characters that are not formatted properly by the CSL parser on Zotero server. In this case we will use less strict matching
    
    if(range.location==NSNotFound){
        
        NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"[^a-z0-9]"
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:NULL];
        NSString* tempFull = [regex stringByReplacingMatchesInString:self.fullCitation options:NULL range:NSMakeRange(0, [self.fullCitation length]) withTemplate:@" "];
        NSString* tempTitle = [regex stringByReplacingMatchesInString:title options:NULL range:NSMakeRange(0, [title length]) withTemplate:@" "];
        range = [tempFull rangeOfString:tempTitle];
    }
    
    //If less strinct matching did not work, give up parsing
    
    if(range.location!=NSNotFound){
        //Anything after the first space after the title is publication details
        NSInteger index = range.location+range.length;
        range = [self.fullCitation rangeOfString:@" " options:0 range:NSMakeRange(index, ([self.fullCitation length]-index))];
        index = (range.location+1);
        if(index<[self.fullCitation length]){
            NSString* publicationTitle = [self.fullCitation substringFromIndex:index];
            return [publicationTitle stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"., "]];
        }
    }

    return @"";
}

-(NSString*) creatorSummary{
    
    if([self.fields count] == 0 || [self.itemType isEqualToString:@"note"] || [self.itemType isEqualToString:@"attachment"]){
        return @"";
    }

    //Anything before the first parenthesis in an APA citation is author unless it is in italic
    
    NSString* authors = (NSString*)[[self.fullCitation componentsSeparatedByString:@" ("] objectAtIndex:0];
    
    if([authors rangeOfString:@"<i>"].location == NSNotFound){
        return authors;
    }
    else return @"";
        
}

-(NSInteger) year{
    NSString* value = [[self fields] objectForKey:@"date"];
    
    NSRange r;
    NSString *regEx = @"[0-9]{4}";
    r = [value rangeOfString:regEx options:NSRegularExpressionSearch];
    
    if (r.location != NSNotFound) {
        return [[value substringWithRange:r] integerValue];
    } else {
    }   return 0; 
}


-(NSString*) itemType{
    return [[self fields] objectForKey:@"itemType"];
}

- (NSArray*) creators{
    if(_creators == NULL){
        [[ZPDatabase instance] addCreatorsToItem:self];
        if(_creators ==NULL) [NSException raise:@"Creators cannot be null" format:@"Reading an item (%@) from database resulted in null creators. ",self.key];
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
            
            //If there is a setter for this field, set it.
            
            NSString* setterString = [key stringByReplacingCharactersInRange:NSMakeRange(0,1)  
                                                                 withString:[[key substringToIndex:1] capitalizedString]];
            
            //Make a setter and use it if it exists
            setterString = [[@"set" stringByAppendingString:setterString]stringByAppendingString: @":"];
            if([self respondsToSelector:NSSelectorFromString(setterString)]){
                [self performSelector:NSSelectorFromString(setterString) withObject:value];
            }

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
