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
    char data[16];
    for (int x=0;x<16;data[x++] = (char)('A' + (arc4random_uniform(26))));
    return [[NSString alloc] initWithBytes:data length:16 encoding:NSUTF8StringEncoding];

}

@end
