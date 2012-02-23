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
        
        [(ZPZoteroItem*) _currentElement setCreators:[data objectForKey:@"creators"]];
        
        //TODO: Tags are include in the JSON, think how they should be processed. (This is for a future version)
        
        NSMutableDictionary* fields = [NSMutableDictionary dictionaryWithDictionary:data];
        
        
        [fields removeObjectForKey:@"creators"];
        [fields removeObjectForKey:@"tags"];
        [(ZPZoteroItem*) _currentElement setFields:fields];
        
    }
    else if(key==@"fullCitation" && [_currentElement isKindOfClass:[ZPZoteroItem class]]){
        
        /*
         
         The full citation is in APA style. This is used to parse the names of the authors and the summary of where the item was published
         
         Example:
         Christensen, C. (1997). <i>The innovator&#x2019;s dilemma&#x202F;: when new technologies cause great firms to fail</i>. Boston&#xA0; Mass.: Harvard Business School Press.
         
         */
        
        ZPZoteroItem* item  = (ZPZoteroItem*) _currentElement;
        
        [item setFullCitation:value];
        
        
        //If there are no authors.
        if(item.creatorSummary==NULL){
            //Anything after the first closing parenthesis is publication details
            NSRange range = [value rangeOfString:@")"];
            if(range.location != NSNotFound) [item setPublicationTitle:[value substringFromIndex:(range.location+1)]];
        }
        else{
            
            //Anything before the first parenthesis is author unless it is in italic
            
            NSString* authors = (NSString*)[[value componentsSeparatedByString:@" ("] objectAtIndex:0];
            
            if([authors rangeOfString:@"<i>"].location != NSNotFound){
                [item setCreatorSummary:authors];
            }
            
            NSRange range = [value rangeOfString:item.title];
            
            //Sometimes the title can contain characters that are not formatted properly by the CSL parser on Zotero server. In this case we will just 
            //give up parsing it
            if(range.location!=NSNotFound){
                //Anything after the first period after the title is publication details
                NSInteger index = range.location+range.length;
                range = [value rangeOfString:@"." options:0 range:NSMakeRange(index, ([value length]-index))];
                index = (range.location+2);
                if(index<[value length]){
                    NSString* publicationTitle = [value substringFromIndex:index];
                    [item setPublicationTitle:publicationTitle];
                }
            }
        }    
        //Trim spaces, periods, and commas from the beginning of the publication detail
        [item setPublicationTitle:[item.publicationTitle stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"., "]]];
    }
    else if([key isEqualToString:@"updated"]){
        [super _setField:@"LastTimestamp" toValue:value];
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
