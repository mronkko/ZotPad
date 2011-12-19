//
//  ZPServerResponseXMLParserCollection.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPServerResponseXMLParser.h"

@interface ZPServerResponseXMLParserCollection : ZPServerResponseXMLParser

- (void) _initNewElementWithID:(NSString*)id;
- (void) _setField:(NSString*)field toValue:(NSString*)value;

@end
