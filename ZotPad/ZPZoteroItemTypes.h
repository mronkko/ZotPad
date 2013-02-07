//
//  ZPZoteroItemTypes.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 2/6/13.
//
//

#import <Foundation/Foundation.h>

@interface ZPZoteroItemTypes : NSObject

+(NSArray*) itemTypes;
+(NSArray*) fieldsForItemType:(NSString*) itemType;
+(NSArray*) creatorTypesForItemType:(NSString*) itemType;

@end
