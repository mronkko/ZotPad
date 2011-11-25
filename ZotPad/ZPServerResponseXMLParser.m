//
//  ZPServerResponseXMLParser.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPServerResponseXMLParser.h"
#import "ZPZoteroLibrary.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroItem.h"

@implementation ZPServerResponseXMLParser

- (id) init{
    self=[super init];
    _resultArray=[NSMutableArray array];
    
        
    _debugParser=FALSE;
    
    return self;

}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName{
    
    if([elementName isEqualToString: @"entry"]){
        [_resultArray addObject:_currentParentElement];    
        _currentParentElement = NULL;
    }
    // HTML elements ( <i> ) inthe formatted citation
    else if([elementName isEqualToString:@"i"]){
        _currentStringContent =[_currentStringContent stringByAppendingString:@"</i>"];
        return;
    }
    else if(_currentElementName!=NULL){
        
        NSString* string = _currentStringContent;

        
        if(_debugParser) NSLog(@"Parser got string %@",string);
        
        if([_currentElementName isEqualToString:@"id"] &&  _resultType == NULL){
            if([string rangeOfString:@"items"].location != NSNotFound){
                _resultType = @"ZPZoteroItem";
            }
            else if([string rangeOfString:@"collections"].location != NSNotFound){
                _resultType = @"ZPZoteroCollection";
            }
            else{
                _resultType = @"ZPZoteroLibrary";
            }
            
        }
        else if([_currentElementName isEqualToString: @"zapi:totalResults"]){
            _totalResults = [string intValue];
        }
        else if(_currentElementName != NULL){
            
            
            
            //These have integer setters and need to be handled separately
            if([_currentElementName isEqualToString: @"zapi:numTags"]){
                [(ZPZoteroItem*) _currentParentElement setNumTags:[string intValue]];
            }
            else if([_currentElementName isEqualToString: @"zapi:numChildren"]){
                [(ZPZoteroItem*) _currentParentElement setNumChildren:[string intValue]];
            }
            else if([_currentElementName isEqualToString: @"zapi:year"]){
                [(ZPZoteroItem*) _currentParentElement setYear:[string intValue]];
            }
            
            
            else if(_currentElementName==@"fullCitation"){
                
                /*
                 
                 The full citation is in APA style. This is used to parse the names of the authors and the summary of where the item was published
                 
                 Example:
                 Christensen, C. (1997). <i>The innovator&#x2019;s dilemma&#x202F;: when new technologies cause great firms to fail</i>. Boston&#xA0; Mass.: Harvard Business School Press.
                 
                 */
                
                ZPZoteroItem* item  = (ZPZoteroItem*) _currentParentElement;
                

                NSRange range = [string rangeOfString:item.title];

                //Sometimes the title can contain characters that are not formatted properly by the CSL parser on Zotero server. In this case we will just 
                //give up parsing it
                
                if(range.location!=NSNotFound){
                    //If the citation starts with the title, there are no authors.
                    if(range.location==0){
                        //Anything after the first closing parenthesis is publication details
                        range = [string rangeOfString:@")"];
                        [item setPublishedIn:[string substringFromIndex:(range.location+1)]];
                    }
                    else{
                        //Anything before the first parenthesis is author
                        NSString* authors = (NSString*)[[string componentsSeparatedByString:@" ("] objectAtIndex:0];
                        [item setAuthors:authors];
                        
                        //Anything after the first period after the title is publication details
                        NSInteger index = range.location+range.length;
                        range = [string rangeOfString:@"." options:NULL range:NSMakeRange(index, ([string length]-index))];
                        index = (range.location+2);
                        if(index<[string length]){
                            NSString* publishedIn = [string substringFromIndex:index];
                            [item setPublishedIn:publishedIn];
                        }
                    }
                    
                    //Trim spaces, periods, and commas from the beginning of the publication detail
                    [item setPublishedIn:[item.publishedIn stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"., "]]];
                }
                else{
                    NSLog(@"Parse error: Could not find title (%@) in referece (%@)",item.title,string);
                }
            }
            //The rest are string and can be handled with selector
            else{
                //Strip zapi: from the element name
                NSString* setterString=[_currentElementName stringByReplacingOccurrencesOfString:@"zapi:" withString:@""];
                
                //capitalize the first letter
                setterString = [setterString stringByReplacingCharactersInRange:NSMakeRange(0,1)  
                                                                     withString:[[setterString substringToIndex:1] capitalizedString]];
                
                //Make a setter and use it if it exists
                setterString = [[@"set" stringByAppendingString:setterString]stringByAppendingString: @":"];
                if([_currentParentElement respondsToSelector:NSSelectorFromString(setterString)]){
                    [_currentParentElement performSelector:NSSelectorFromString(setterString) withObject:string];
                }
            }
        }
    }
    _currentElementName = NULL;
    _currentStringContent = NULL;
    
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict{

    if(_debugParser) NSLog(@"Parser starting element %@",elementName);
    
    // Elements related to one library, item, or collection 
    if (_currentParentElement!=NULL){
        
        //Elements that contain the information as content
        
        if(([ elementName isEqualToString: @"title"]) ||
           [ elementName isEqualToString: @"published"] ||
           [ elementName hasPrefix:@"zapi:"]){
            _currentElementName=elementName;
            _currentStringContent =@"";
        }
       
        else if([elementName isEqualToString:@"div"] && [@"csl-entry" isEqualToString:[attributeDict objectForKey:@"class"]]){
            _currentElementName=@"fullCitation";
            _currentStringContent =@"";
        }
        
        
        //Elements that contain information as attributes
        
        
        else if(_currentParentElement!= NULL && [elementName isEqualToString: @"link" ]){
            
            
            NSString* selectorString=NULL;
            
            //The value is URL and we want to get the part after last /
            NSString* value = [[(NSString*)[attributeDict objectForKey:@"href"] componentsSeparatedByString:@"/"]lastObject];
            //Strip URL parameters
            value = [[value componentsSeparatedByString:@"?"] objectAtIndex:0];    
            
            if([@"self" isEqualToString:(NSString*)[attributeDict objectForKey:@"rel"]]){
                selectorString = @"setKey:";
            }
            else if([@"up" isEqualToString:(NSString*)[attributeDict objectForKey:@"rel"]]){
                selectorString = @"setParentKey:";
            }
            
            if(selectorString != NULL){
                if(_debugParser){
                    NSLog(@"%@",_resultType);
                    NSLog(@"%@",selectorString);
                }
                [_currentParentElement performSelector:NSSelectorFromString(selectorString) withObject:value];
            }
        }
        // HTML elements ( <i> ) inthe formatted citation
        else if([elementName isEqualToString:@"i"]){
            _currentStringContent =[_currentStringContent stringByAppendingString:@"<i>"];
        }
    } 
    // The first ID tag will tell us what the request was
    else if([elementName isEqualToString: @"zapi:totalResults"] || [elementName isEqualToString: @"id"]){
        _currentElementName = elementName;
        _currentStringContent =@"";
    }
    else if([elementName isEqualToString: @"entry"]){
        _currentParentElement =  [[NSClassFromString(_resultType) alloc] init];
    }
    
   

}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{

    if(_currentElementName!=NULL){
        _currentStringContent =[_currentStringContent stringByAppendingString:string];
    }
    
}

- (NSArray*) parsedElements{
    return _resultArray;
}
- (NSInteger) totalResults{
    return _totalResults;
}


@end
