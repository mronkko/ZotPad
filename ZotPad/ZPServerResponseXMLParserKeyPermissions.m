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
        NSString* library =[attributeDict objectForKey:@"library"];
        NSString* group = [attributeDict objectForKey:@"group"];
        if(library!= NULL){
            [_results addObject:[NSString stringWithFormat:@"%i",ZPLIBRARY_ID_MY_LIBRARY]];
        }
        else if(group!=NULL){
            [_results addObject:group];
        }
    }
}

- (NSArray*) results{
    return  _results;
}

@end
