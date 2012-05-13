//
//  ZPServerResponseXMLParserKeyPermissions.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 13.5.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPServerResponseXMLParser.h"

@interface ZPServerResponseXMLParserKeyPermissions : NSObject <NSXMLParserDelegate>{
    NSMutableArray* _results;
}

- (NSArray*) results;

@end
