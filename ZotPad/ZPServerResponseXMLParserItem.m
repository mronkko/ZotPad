//
//  ZPServerResponseXMLParserItem.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPServerResponseXMLParserItem.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroAttachment.h"
#import "ZPZoteroNote.h"
#import "ZPDatabase.h"

#import "SBJson.h"

@implementation ZPServerResponseXMLParserItem

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName{
    
    if(_jsonContent && ! [elementName isEqualToString:@"i"] ){
        _jsonContent = FALSE;
        [self _setField:@"json" toValue:_currentStringContent];
    }else if(_bibContent && ! [elementName isEqualToString:@"i"]){
        _bibContent = FALSE;
        [self _setField:@"fullCitation" toValue:_currentStringContent];
    }
    else{
        [super parser:parser didEndElement:elementName namespaceURI:namespaceURI qualifiedName:qName];
    }
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict{
    
    if (_insideEntry){
        
        if([elementName isEqualToString:@"div"] && [@"csl-entry" isEqualToString:[attributeDict objectForKey:@"class"]]){
            _bibContent=TRUE;
        }
        //Item as JSON content
        else if([elementName isEqualToString:@"zapi:subcontent"] && [@"json" isEqualToString:[attributeDict objectForKey:@"zapi:type"]]){
            _jsonContent=TRUE;
        }
    }
    
    [super parser:parser didStartElement:elementName namespaceURI:namespaceURI qualifiedName:qualifiedName attributes:attributeDict];
    
}

- (void) _setField:(NSString*)key toValue:(NSString*)value{
    
    if(_currentElement == NULL){
        [super _setField:key toValue:value];
    }
    else if([key isEqualToString: @"json"] && [_currentElement isKindOfClass:[ZPZoteroItem class]] && 
            ! ([_currentElement isKindOfClass:[ZPZoteroAttachment class]] || [_currentElement isKindOfClass:[ZPZoteroNote class]]) ){

        //PARSE JSON CONTENT
        NSDictionary* data = [value JSONValue];
        
        //The creators do not have a field for authorOrder in the Zotero API, so this needs to be added
        NSArray* authors = [data objectForKey:@"creators"];
        NSMutableArray* fixedAuthors= [NSMutableArray arrayWithCapacity:[authors count]];
        NSInteger counter=0;
        for(NSDictionary* author in authors){
            NSMutableDictionary* fixedAuthor = [NSMutableDictionary dictionaryWithDictionary:author];
            [fixedAuthor setValue:[NSNumber numberWithInt:counter] forKey:@"authorOrder"];
            [fixedAuthors addObject:fixedAuthor];
            counter++;
        }
        [(ZPZoteroItem*) _currentElement setCreators:fixedAuthors];
        
        //TODO: Tags are include in the JSON, think how they should be processed. (This is for a future version)
        
        NSMutableDictionary* fields = [NSMutableDictionary dictionaryWithDictionary:data];
        
        
        [fields removeObjectForKey:@"creators"];
        [fields removeObjectForKey:@"tags"];
        [(ZPZoteroItem*) _currentElement setFields:fields];
        
    }
    else if([key isEqualToString:@"updated"]){
        [super _setField:@"serverTimestamp" toValue:value];
    }
    else{
        [super _setField:key toValue:value];
    }
}
- (void) _initNewElementWithID:(NSString*)id{
    //Choose what to create based on the item type 
    NSString* itemType = [_temporaryFieldStorage objectForKey:@"zapi:itemType"];
    
    if([itemType isEqualToString:@"attachment"]){
        _currentElement = [ZPZoteroAttachment dataObjectWithKey:id];
    }
    else if([itemType isEqualToString:@"note"]){
        //Notes are really note implemented yet
        _currentElement = [ZPZoteroNote dataObjectWithKey:id];
    }
    else{
        //IF the item does not exist in the in-memory cache, attempt to load it from the disk cache 
        _currentElement = [ZPZoteroItem dataObjectWithKey:id];
    }
    [(ZPZoteroItem*)_currentElement setLibraryID:_libraryID];
    [super _processTemporaryFieldStorage];
}

@end
