//
//  ZPServerResponseXMLParser.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPServerResponseXMLParser.h"

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


    if([elementName isEqualToString: @"entry"]){
        _currentParentElement = [NSMutableDictionary dictionary];
    }
    //Elements that contain the information as content
    else if(_currentParentElement!= NULL && [ elementName isEqualToString: @"title"]){
        _currentElementName = elementName;
    }
    //Elements that contain information as attributes
    else if(_currentParentElement!= NULL && [elementName isEqualToString: @"link" ]){
        if([@"self" isEqualToString:(NSString*)[attributeDict objectForKey:@"rel"]]){
            [_currentParentElement setObject:[[(NSString*)[attributeDict objectForKey:@"href"] componentsSeparatedByString:@"/"]lastObject] forKey:@"id"];
        }
        if([@"up" isEqualToString:(NSString*)[attributeDict objectForKey:@"rel"]]){
            [_currentParentElement setObject:[[(NSString*)[attributeDict objectForKey:@"href"] componentsSeparatedByString:@"/"]lastObject] forKey:@"parentID"];
        }

    }

}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{
    if(_currentElementName != NULL){
        [_currentParentElement setValue:string forKey:_currentElementName];
    }
}

- (NSArray*) results{
    return _resultArray;
}


@end
