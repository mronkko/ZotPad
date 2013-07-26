//
//  ZPServerResponseXMLParser.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/22/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "ZPServerResponseXMLParser.h"

//Neded for citation formatting debugging

#import "NSString_stripHtml.h"

//TODO: parse this from collections <zapi:numItems>0</zapi:numItems>

@implementation ZPServerResponseXMLParser

#ifdef ZPDEBUG
@synthesize fullResponse;
#endif

@synthesize parsedElements = _resultArray;

- (id) init{
    self=[super init];
    _resultArray=[NSMutableArray array];
    _temporaryFieldStorage =[NSMutableDictionary dictionary];
    _insideEntry=FALSE;
    _currentID=NULL;
    
    return self;
    
}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName{
    
    //    DDLogVerbose(@"Parser finished element %@ with content %@",elementName,_currentStringContent);
    
    // HTML elements ( <i> ) in the formatted citation
    if([elementName isEqualToString:@"i"]){
        [_currentStringContent appendString:@"</i>"];
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
            //Current element MUST have a libraryID
            if(_currentElement.libraryID == ZPLIBRARY_ID_NOT_SET) [NSException raise:@"Data object is missing library ID" format:@"All data objects must have library ID. Object with missing Library ID: %@",_currentElement];
            
            //If this is a standalone note, add itself as a parent
            if([_currentElement isKindOfClass:[ZPZoteroAttachment class]] && [(ZPZoteroAttachment*) _currentElement parentKey] == NULL){
                ZPZoteroItem* standAloneParent = [ZPZoteroItem itemWithKey:_currentElement.key];
                standAloneParent.title = _currentElement.title;
                standAloneParent.fields = [NSDictionary dictionaryWithObject:ZPKEY_ATTACHMENT forKey:@"itemType"];
                standAloneParent.attachments = [NSArray arrayWithObject:_currentElement];
                standAloneParent.libraryID = _currentElement.libraryID;
                standAloneParent.etag = _currentElement.etag;
                standAloneParent.needsToBeWrittenToCache = _currentElement.needsToBeWrittenToCache;
                [(ZPZoteroAttachment*) _currentElement setParentKey:_currentElement.key];
                [_resultArray addObject:standAloneParent];
            }
            //If this is a standalone attachment, add itself as a parent
            else if([_currentElement isKindOfClass:[ZPZoteroNote class]] && [(ZPZoteroNote*) _currentElement parentKey] == NULL){
                ZPZoteroItem* standAloneParent = [ZPZoteroItem itemWithKey:_currentElement.key];
                standAloneParent.title = _currentElement.title;
                standAloneParent.notes = [NSArray arrayWithObject:_currentElement];
                standAloneParent.fields = [NSDictionary dictionaryWithObject:@"note" forKey:@"itemType"];
                standAloneParent.libraryID = _currentElement.libraryID;
                standAloneParent.etag = _currentElement.etag;
                standAloneParent.needsToBeWrittenToCache = _currentElement.needsToBeWrittenToCache;
                [(ZPZoteroNote*) _currentElement setParentKey:_currentElement.key];
                [_resultArray addObject:standAloneParent];
            }
            
            [_resultArray addObject:_currentElement];
            
            if([ZPPreferences debugCitationParser] && [_currentElement isKindOfClass:[ZPZoteroItem class]] && _formattedCitationForDebug != NULL){
                NSString* generatedCitation = [(ZPZoteroItem*) _currentElement fullCitation];
                if(![[generatedCitation stripHtml] isEqualToString:[_formattedCitationForDebug stripHtml]]){
                    DDLogError(@"Citation created by local CSL formatter differs from citation received from Zotero server.\n\nCitation from Zotero:\n%@\n\nLocally generated citation:\n%@\n\nJSON data\n:%@",
                               _formattedCitationForDebug,
                               generatedCitation,
                               [(ZPZoteroItem*) _currentElement jsonFromServer]);
                }
            }
            _formattedCitationForDebug = NULL;
            _currentElement = NULL;
            _insideEntry = FALSE;
            
            if(_totalResults ==0 ) _totalResults = 1;
        }
        else if(_insideEntry && _currentStringContent != nil){
            [self _setField:elementName toValue:_currentStringContent];
        }
        
        _currentStringContent = nil;
    }
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict{
    
    //    DDLogVerbose(@"Parser starting element %@",elementName);
    
    // HTML elements ( <i> ) inthe formatted citation
    
    if([elementName isEqualToString:@"i"]){
        [_currentStringContent appendString:@"<i>"];
    }
    else{
        _currentStringContent = [[NSMutableString alloc] init];
        
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
                
                //The value is URL and we want to get the part after last /
                if([[parts objectAtIndex:3] isEqualToString:@"users"]){
                    _libraryID = ZPLIBRARY_ID_MY_LIBRARY;
                }
                else{
                    _libraryID = [[parts objectAtIndex:4] intValue];
                }
                
            }
            else if([@"up" isEqualToString:(NSString*)[attributeDict objectForKey:@"rel"]]){
                [self _setField:@"parentKey" toValue:value];
            }
            else if([@"enclosure" isEqualToString:(NSString*)[attributeDict objectForKey:@"rel"]]){
                
                //For now only use enclosures that point to a file
                //NSString* type=[attributeDict objectForKey:@"type"];
                NSString* length=[attributeDict objectForKey:@"length"];
                
                [self _setField:@"existsOnZoteroServer" toValue:[NSNumber numberWithInt:1]];
                
                if(length!=NULL){
                    [self _setField:@"attachmentSize" toValue:[NSNumber numberWithInt:[length intValue]]];
                }
            }
        }
    }
}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{
    if(_currentStringContent != nil) [_currentStringContent appendString:string];
}

- (NSInteger) totalResults{
    return _totalResults;
}

- (NSString*) updateTimestamp{
    return _updateTimestamp;
}


- (void) _setField:(NSString*)field toValue:(NSObject*)value{
    if(_currentElement==NULL){
        [_temporaryFieldStorage setObject:value forKey:field];
    }
    else{
        //Strip zapi: from the element name
        NSString* attributeName=[field stringByReplacingOccurrencesOfString:@"zapi:" withString:@""];
        
        if([_currentElement respondsToSelector:NSSelectorFromString(attributeName)]){
            [_currentElement setValue:value forKey:attributeName];
        }
        else{
            //            DDLogVerbose(@"XML parser rejected field %@",attributeName);
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
