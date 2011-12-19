//
//  ZPServerResponseXMLParserItem.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPServerResponseXMLParserItem.h"
#import "ZPZoteroItem.h"
#import "SBJson.h"

@implementation ZPServerResponseXMLParserItem

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName{
    
    if(_jsonContent){
        _jsonContent = FALSE;
        [self _setField:@"json" toValue:_currentStringContent];
    }else if(_bibContent){
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
        else if([elementName isEqualToString:@"content"] && [@"application/json" isEqualToString:[attributeDict objectForKey:@"type"]]){
            _jsonContent=TRUE;
        }
    }
    
    [super parser:parser didStartElement:elementName namespaceURI:namespaceURI qualifiedName:qualifiedName attributes:attributeDict];
    
}

-(void) setValue:(id)value forKey:(NSString *)key{
    
    if([key isEqualToString:@"id"]){
        _currentElement = [ZPZoteroItem ZPZoteroItemWithKey:value];
        [super _processTemporaryFieldStorage];
    }
    else if(_currentElement != NULL){
        
        if([key isEqualToString: @"json"]){
            //PARSE JSON CONTENT
            NSDictionary* data = [value JSONValue];
            
            [(ZPZoteroItem*) _currentElement setCreators:[data objectForKey:@"creators"]];
            
            //TODO: Tags are include in the JSON, think how they should be processed. (This is for a future version)
            
            NSMutableDictionary* fields = [NSMutableDictionary dictionaryWithDictionary:data];
            [fields removeObjectForKey:@"creators"];
            [fields removeObjectForKey:@"tags"];
            [(ZPZoteroItem*) _currentElement setFields:fields];
            
        }
        else if(key==@"fullCitation"){
            
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
                [item setPublishedIn:[value substringFromIndex:(range.location+1)]];
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
                        NSString* publishedIn = [value substringFromIndex:index];
                        [item setPublishedIn:publishedIn];
                    }
                }
            }    
            //Trim spaces, periods, and commas from the beginning of the publication detail
            [item setPublishedIn:[item.publishedIn stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"., "]]];
        }
        else if([key isEqualToString: @"zapi:numTags"]){
            [(ZPZoteroItem*) _currentElement setNumTags:[value intValue]];
        }
        else if([key isEqualToString: @"zapi:numChildren"]){
            [(ZPZoteroItem*) _currentElement setNumChildren:[value intValue]];
        }
        else if([key isEqualToString: @"zapi:year"]){
            [(ZPZoteroItem*) _currentElement setYear:[value intValue]];
        }
    }
    else{
        [super setValue:value forKey:key];
    }
}
- (void) _initNewElementWithID:(NSString*)id{
    _currentElement = [ZPZoteroItem ZPZoteroItemWithKey:id];
    [super _processTemporaryFieldStorage];
}

@end
