//
//  ZPUtils.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 1/1/13.
//
//

#import "ZPUtils.h"

@implementation ZPUtils

+(NSString*)randomString{
    char data[8];
    for (int x=0;x<8;data[x++] = (char)('A' + (arc4random_uniform(26))));
    return [[NSString alloc] initWithBytes:data length:8 encoding:NSUTF8StringEncoding];

}

@end
