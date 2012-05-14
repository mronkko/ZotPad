//
//  ZPServerResponseXMLParserLibrary.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPCore.h"

#import "ZPServerResponseXMLParserLibrary.h"
#import "ZPZoteroLibrary.h"

@implementation ZPServerResponseXMLParserLibrary

- (void) _initNewElementWithID:(NSString*)id{
    _currentElement = [ZPZoteroLibrary dataObjectWithKey:[NSNumber numberWithInteger:[id intValue]]];
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
        [(ZPZoteroLibrary*) _currentElement setServerTimestamp:value];
    }
    //TODO: Libraries have items and collections as children. Make a clear separation here. 
    /*
    else if([field isEqualToString:@"zapi:numItems"]){
        [(ZPZoteroLibrary*) _currentElement setNumChildren:[NSNumber numberWithInt:[value intValue]]];
    }
    */
    else{
        [super _setField:field toValue:value];
    }
}


@end
