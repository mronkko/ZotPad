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
    return self;

}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName{

    if([elementName isEqualToString: @"entry"]){
        [_resultArray addObject:_currentParentElement];    
        _currentParentElement = NULL;
    }
    _currentElementName = NULL;

}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict{

    // Elements related to one library, item, or collection 
    if (_currentParentElement!=NULL){
        
        //Elements that contain the information as content
        
        if(([ elementName isEqualToString: @"title"]) ||
           [ elementName isEqualToString: @"published"] ||
           [ elementName hasPrefix:@"zapi:"]){
            _currentElementName=elementName;
        }
        else if([elementName isEqualToString:@"div"] && [@"csl-entry" isEqualToString:[attributeDict objectForKey:@"class"]]){
            _currentElementName=@"fullCitation";
        }
        //Elements that contain information as attributes
        else if(_currentParentElement!= NULL && [elementName isEqualToString: @"link" ]){
            
            SEL selector;
            
            if([@"self" isEqualToString:(NSString*)[attributeDict objectForKey:@"rel"]]){
                selector = NSSelectorFromString(@"setKey");
            }
            else if([@"up" isEqualToString:(NSString*)[attributeDict objectForKey:@"rel"]]){
                selector = NSSelectorFromString(@"setParentKey");
            }
            
            if(selector != NULL){

                //The value is URL and we want to get the part after last /
                NSString* value = [[(NSString*)[attributeDict objectForKey:@"href"] componentsSeparatedByString:@"/"]lastObject];
                //Strip URL parameters
                value = [[value componentsSeparatedByString:@"?"] objectAtIndex:0];                

                [_currentParentElement performSelector:selector withObject:value];
            }
        }
    } 
    // The first ID tag will tell us what the request was
    else if([elementName isEqualToString: @"entry"]){
        _currentParentElement =  [[NSClassFromString(_resultType) alloc] init];
    }
    
    else if([elementName isEqualToString: @"zapi:totalResults"]){
        _currentElementName = elementName;
    }


}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{

    if([_currentElementName isEqualToString:@"id"]){
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
        
        //Strip zapi: from the element name
        NSString* setterString=[_currentElementName stringByReplacingOccurrencesOfString:@"zapi:" withString:@""];
        
        //capitalize the first letter
        setterString = [setterString stringByReplacingCharactersInRange:NSMakeRange(0,1)  
                    withString:[[setterString substringToIndex:1] capitalizedString]];
        
        //Make a setter
        setterString = [@"set" stringByAppendingString:setterString];
        
        SEL selector = NSSelectorFromString(setterString);
        [_currentParentElement performSelector:selector withObject:string];
    }
}

- (NSArray*) parsedElements{
    return _resultArray;
}


@end
