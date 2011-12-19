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
    _currentElement = [ZPZoteroCollection ZPZoteroCollectionWithKey:id];
    [super _processTemporaryFieldStorage];
}

/*
 
 Translate results to appropriate attributes
 
 */

- (void) _setField:(NSString*)field toValue:(NSString*)value{
    
    if([field isEqualToString:@"updated"]) field =@"ServerTimeStamp";
    
    [super _setField:field toValue:value];
}


@end
