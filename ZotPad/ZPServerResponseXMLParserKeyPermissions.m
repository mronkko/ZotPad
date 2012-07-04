//
//  ZPServerResponseXMLParserKeyPermissions.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 13.5.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "ZPServerResponseXMLParserKeyPermissions.h"

@implementation ZPServerResponseXMLParserKeyPermissions

-(id)init{
    self=[super init];
    
    _results = [[NSMutableArray alloc] init];
    return self;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict{
    if([elementName isEqualToString:@"access"]){
        NSString* libraryID =[attributeDict objectForKey:@"library"];
        if(libraryID == NULL) libraryID =[attributeDict objectForKey:@"group"];
        [_results addObject:libraryID];
    }
}

- (NSArray*) results{
    return  _results;
}

@end
