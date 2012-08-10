//
//  ZPServerResponseXMLParser.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/22/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPServerResponseXMLParser : NSObject <NSXMLParserDelegate>{
    NSMutableArray* _resultArray;
    NSMutableDictionary* _temporaryFieldStorage;
    NSInteger _totalResults;
    NSString* _currentStringContent;
    BOOL _insideEntry;
    NSObject* _currentElement;
    NSString* _updateTimestamp;
    NSNumber* _libraryID;
    NSString* _currentID;
}

#ifdef ZPDEBUG
//@property (retain) NSString* fullResponse;
#endif
@property (retain) NSArray* parsedElements;


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName;
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict;
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string;

- (NSInteger) totalResults;
- (NSString*) updateTimestamp;

- (void) _setField:(NSString*)field toValue:(NSString*)value;
- (void) _initNewElementWithID:(NSString*)id;
- (void) _processTemporaryFieldStorage;

@end
