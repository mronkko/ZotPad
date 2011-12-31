//
//  ZPServerResponseXMLParser.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPServerResponseXMLParser.h"

//TODO: parse this from collections <zapi:numItems>0</zapi:numItems>

@implementation ZPServerResponseXMLParser


- (id) init{
    self=[super init];
    _resultArray=[NSMutableArray array];
    _temporaryFieldStorage =[NSMutableDictionary dictionary];
//    _debugParser=TRUE;
    _currentStringContent = @"";
    _insideEntry=FALSE;
    _currentID=NULL; 
    
    return self;

}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName{
    
    if(_debugParser) NSLog(@"Parser finished element %@ with content %@",elementName,_currentStringContent);
    
    // HTML elements ( <i> ) in the formatted citation
    if([elementName isEqualToString:@"i"]){
        _currentStringContent =[_currentStringContent stringByAppendingString:@"</i>"];
    }
    else{
        if([elementName isEqualToString: @"zapi:totalResults"]){
            _totalResults = [_currentStringContent intValue];
        }
        //Only the updated field that is for the whole request
        if(!_insideEntry && [elementName isEqualToString: @"updated"]){
            if(_updateTimestamp != NULL){
                [NSException raise:@"Zotero server response parser exception" format:@"We got a second time stamp. The first was %@ and the second %@.",_updateTimestamp,_currentStringContent];
            }
            _updateTimestamp = _currentStringContent;
        }
        else if([elementName isEqualToString: @"entry"]){
            
            [self _initNewElementWithID:_currentID];
            [self _processTemporaryFieldStorage];
            [_resultArray addObject:_currentElement];
            
            _currentElement = NULL;
            _insideEntry = FALSE;
            
            if(_totalResults ==0 ) _totalResults = 1;
        }
        else if(_insideEntry){
            [self _setField:elementName toValue:_currentStringContent];
        }
    }
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict{

    if(_debugParser) NSLog(@"Parser starting element %@",elementName);

    // HTML elements ( <i> ) inthe formatted citation

    if([elementName isEqualToString:@"i"]){
        _currentStringContent =[_currentStringContent stringByAppendingString:@"<i>"];
    } 
    else{
        _currentStringContent = @"";
        
        if([elementName isEqualToString:@"entry"]){
            _insideEntry = TRUE;
        }
        else if (_insideEntry && [elementName isEqualToString: @"link" ]){
            
            //The value is URL and we want to get the part after last /
            NSArray* parts= [(NSString*)[attributeDict objectForKey:@"href"] componentsSeparatedByString:@"/"];
            
            //Strip URL parameters
            NSString* value = [[[parts lastObject] componentsSeparatedByString:@"?"] objectAtIndex:0];    
            
            if([@"self" isEqualToString:(NSString*)[attributeDict objectForKey:@"rel"]]){
                _currentID = value;
            }
            else if([@"up" isEqualToString:(NSString*)[attributeDict objectForKey:@"rel"]]){
                [self _setField:@"ParentKey" toValue:value];
            }
            else if([@"enclosure" isEqualToString:(NSString*)[attributeDict objectForKey:@"rel"]]){
                [self _setField:@"AttachmentURL" toValue:[attributeDict objectForKey:@"href"]];
                [self _setField:@"AttachmentType" toValue:[attributeDict objectForKey:@"type"]];
                [self _setField:@"AttachmentTitle" toValue:[attributeDict objectForKey:@"title"]];
                [self _setField:@"AttachmentLength" toValue:[attributeDict objectForKey:@"length"]];
            }

            
        }
        else if (! _insideEntry && [elementName isEqualToString: @"link" ]){

            if([@"self" isEqualToString:(NSString*)[attributeDict objectForKey:@"rel"]]){

                //The value is URL and we want to get the part after last /
                NSArray* parts= [(NSString*)[attributeDict objectForKey:@"href"] componentsSeparatedByString:@"/"];
            
                
                if([[parts objectAtIndex:3] isEqualToString:@"users"]){
                    _libraryID = [NSNumber numberWithInt:1];
                }
                else{
                    _libraryID = [NSNumber numberWithInt:[[parts objectAtIndex:4] intValue]];
                }
            }
        }
    }
}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{

    _currentStringContent =[_currentStringContent stringByAppendingString:string];
}

- (NSArray*) parsedElements{
    return _resultArray;
}
- (NSInteger) totalResults{
    return _totalResults;
}

- (NSString*) updateTimestamp{
    return _updateTimestamp;
}


- (void) _setField:(NSString*)field toValue:(NSString*)value{
    if(_currentElement==NULL){
        [_temporaryFieldStorage setObject:value forKey:field];
    }
    else{
        //Strip zapi: from the element name
        NSString* setterString=[field stringByReplacingOccurrencesOfString:@"zapi:" withString:@""];
        
        //capitalize the first letter
        setterString = [setterString stringByReplacingCharactersInRange:NSMakeRange(0,1)  
                                                             withString:[[setterString substringToIndex:1] capitalizedString]];
        
        //Make a setter and use it if it exists
        setterString = [[@"set" stringByAppendingString:setterString]stringByAppendingString: @":"];
        if([_currentElement respondsToSelector:NSSelectorFromString(setterString)]){
            [_currentElement performSelector:NSSelectorFromString(setterString) withObject:value];
        }
    }

}

- (void) _processTemporaryFieldStorage{

    for(NSString *key in _temporaryFieldStorage){
        
        NSString* value = [_temporaryFieldStorage valueForKey:key];
        [self _setField:key toValue:value];
    }
    [_temporaryFieldStorage removeAllObjects];

}


//Implement this to subclass
- (void) _initNewElementWithID:(NSString*)id {
    [NSException raise:@"Method not implemented" format:@"You need to implement _initNewWlementWithID to a subclass of ZPServerResponseXMLParser."];
}


@end