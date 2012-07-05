//
//  ZPServerResponseXMLParserItem.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPServerResponseXMLParser.h"

@interface ZPServerResponseXMLParserItem : ZPServerResponseXMLParser{
    BOOL _bibContent;
    BOOL _jsonContent;
}
- (void) _setField:(NSString*)field toValue:(NSString*)value;
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict;
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName;

- (void) _initNewElementWithID:(NSString*)id;


@end
