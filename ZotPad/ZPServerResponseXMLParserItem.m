//
//  ZPServerResponseXMLParserItem.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "ZPServerResponseXMLParserItem.h"
#import "SBJson.h"

@implementation ZPServerResponseXMLParserItem

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName{
    
    if(_jsonContent && ! [elementName isEqualToString:@"i"] ){
        _jsonContent = FALSE;
        [self _setField:@"json" toValue:_currentStringContent];
    }else if(_bibContent && ! [elementName isEqualToString:@"i"]){
        _bibContent = FALSE;
        _formattedCitationForDebug = _currentStringContent;
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
        else if(([elementName isEqualToString:@"zapi:subcontent"] || [elementName isEqualToString:@"content"]) && [@"json" isEqualToString:[attributeDict objectForKey:@"zapi:type"]]){
            _jsonContent=TRUE;
            //Get the etag for the item
            [super _setField:@"etag" toValue:[attributeDict objectForKey:@"zapi:etag"]];
        }
    }
    
    [super parser:parser didStartElement:elementName namespaceURI:namespaceURI qualifiedName:qualifiedName attributes:attributeDict];
    
}

- (void) _setField:(NSString*)key toValue:(NSString*)value{
    
    if(_currentElement == NULL){
        [super _setField:key toValue:value];
    }
    else if([key isEqualToString: @"json"]){
        
        //Store the json as it is to enable more robust item editing
        [super _setField:@"jsonFromServer" toValue:value];

        //PARSE JSON CONTENT
        NSDictionary* data = [value JSONValue];
        
        //The creators do not have a field for authorOrder in the Zotero API, so this needs to be added
        NSArray* authors = [data objectForKey:@"creators"];
        if(authors != NULL){
            [(ZPZoteroItem*) _currentElement setCreators:authors];
        }
        NSArray* tags = [data objectForKey:@"tags"];


        if(tags != NULL){
            NSMutableArray* tagsArray = [[NSMutableArray alloc] initWithCapacity:[tags count]];
            for(NSDictionary* tagDict in tags){
                [tagsArray addObject:[tagDict objectForKey:@"tag"]];
            }

            //If the tags have changed on the server, force writing this item in the DB
            
            NSArray* newTags = [tagsArray sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
            if(![_currentElement.tags isEqualToArray:newTags]){
                _currentElement.tags = newTags;
                _currentElement.needsToBeWrittenToCache = TRUE;
            }
        }
        
        NSMutableDictionary* fields = [NSMutableDictionary dictionaryWithDictionary:data];
        
        
        [fields removeObjectForKey:@"creators"];
        [fields removeObjectForKey:@"tags"];
        
        NSString* linkModeString = [fields objectForKey:@"linkMode"];
        
        if(linkModeString!=NULL){
            NSInteger linkMode;
            if([linkModeString isEqualToString:@"imported_file"]) linkMode = LINK_MODE_IMPORTED_FILE;
            else if([linkModeString isEqualToString:@"imported_url"]) linkMode = LINK_MODE_IMPORTED_URL;
            else if([linkModeString isEqualToString:@"linked_url"]) linkMode = LINK_MODE_LINKED_URL;
            else if([linkModeString isEqualToString:@"linked_file"]) linkMode = LINK_MODE_LINKED_FILE;
            
            //If we get garbage, throw exception
            else{
                [NSException raise:@"Invalid link mode" format:@"Server returned invalid link mode for attachment"];
            }
            
            [super _setField:@"linkMode" toValue:[NSNumber numberWithInt:linkMode]];
            [fields removeObjectForKey:@"linkMode"];
            
        }

        if([_currentElement isKindOfClass:[ZPZoteroItem class]]){
            [(ZPZoteroItem*) _currentElement setFields:fields];
        }
        //Notes and attachments do not have fields.
        else{
            NSEnumerator* e = [fields keyEnumerator];
            NSString* key;

            while(key = [e nextObject]){
                NSString* value = [fields objectForKey:key];
                if(![value isEqual:@""]){
                    if([_currentElement respondsToSelector:NSSelectorFromString(key)]){
                        if((NSObject*) value==[NSNull null]) value = nil;
                        [_currentElement setValue:value forKey:key];
                    }
                }
            }
        }
        
    }
    else if([key isEqualToString:@"published"]){
        [super _setField:@"dateAdded" toValue:value];
    }
    else if([key isEqualToString:@"updated"]){
        NSString* ts1 = _currentElement.cacheTimestamp;
        NSString* ts2 = value;
        BOOL write = ! [ts2 isEqualToString:ts1];
        _currentElement.needsToBeWrittenToCache = write;

        [super _setField:@"serverTimestamp" toValue:value];
    }
    else{
        [super _setField:key toValue:value];
    }
}
- (void) _initNewElementWithID:(NSString*)id{
    //Choose what to create based on the item type 
    NSString* itemType = [_temporaryFieldStorage objectForKey:@"zapi:itemType"];
    
    if([itemType isEqualToString:ZPKEY_ATTACHMENT]){
        _currentElement = [ZPZoteroAttachment attachmentWithKey:id];
    }
    else if([itemType isEqualToString:@"note"]){
        _currentElement = [ZPZoteroNote noteWithKey:id];
    }
    else{
        //IF the item does not exist in the in-memory cache, attempt to load it from the disk cache 
        _currentElement = [ZPZoteroItem itemWithKey:id];
    }
    [(ZPZoteroItem*)_currentElement setLibraryID:_libraryID];
    [super _processTemporaryFieldStorage];
    
}

@end
