//
//  ZPServerResponseXMLParserCollection.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPServerResponseXMLParserCollection.h"
#import "ZPZoteroCollection.h"

@implementation ZPServerResponseXMLParserCollection


- (void) _initNewElementWithID:(NSString*)id{
    _currentElement = [ZPZoteroCollection dataObjectWithKey:id];
    [(ZPZoteroCollection*)_currentElement setLibraryID:_libraryID];
    [super _processTemporaryFieldStorage];
}

/*
 
 Translate results to appropriate attributes
 
 */

- (void) _setField:(NSString*)field toValue:(NSString*)value{
  
    if (_currentElement == NULL){ 
        [super _setField:field toValue:value];
    }
    else if([field isEqualToString:@"updated"]){
        [(ZPZoteroCollection*) _currentElement setServerTimestamp:value];
    }
    else if([field isEqualToString:@"zapi:numItems"]){
        [(ZPZoteroCollection*) _currentElement setNumChildren:[NSNumber numberWithInt:[value intValue]]];
    }
    else{
        [super _setField:field toValue:value];
    }

}


@end
