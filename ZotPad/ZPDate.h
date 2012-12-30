//
//  ZPDate.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 12/30/12.
//
//


// TODO: Implement date part (e.g. Summer)

#import <Foundation/Foundation.h>

@interface ZPDate : NSObject

@property (assign) NSInteger year;
@property (assign) NSInteger month;
@property (assign) NSInteger day;

+(ZPDate*) strToDate:(NSString*) dateString;

-(NSString*) ISOString;

@end
