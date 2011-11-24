//
//  ZPServerResponseXMLParser.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPServerResponseXMLParser : NSObject <NSXMLParserDelegate>{
    NSMutableArray* _resultArray;

    //Either a ZPNavigatorNode or ZPZoteroItem
    NSObject* _currentParentElement;
    
    NSString* _currentElementName;
    NSString* _resultType;
    NSInteger _totalResults;
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName;
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict;
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string;
- (NSInteger) totalResults;
- (NSArray*) parsedElements;

@end
