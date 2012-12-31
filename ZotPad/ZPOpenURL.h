//
//  ZPOpenURL.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 12/29/12.
//
//
#import "ZPCore.h"
#import <Foundation/Foundation.h>

@interface ZPOpenURL : NSObject;

@property (retain, readonly) NSDictionary* fields;

-(id) initWithZoteroItem:(ZPZoteroItem*) item;
-(NSString*) version;
-(NSString*) URLString;

@end
