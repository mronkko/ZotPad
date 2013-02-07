//
//  ZPZoteroItemTypes.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 2/6/13.
//
//

#import "ZPZoteroItemTypes.h"
#import "TouchXML.h"

@implementation ZPZoteroItemTypes

+(NSArray*) itemTypes{
    
    NSData* fieldMapData   = [NSData dataWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"typeMap" ofType: @"xml"]];
    
    CXMLDocument* fieldMapDoc = [[CXMLDocument alloc] initWithData:fieldMapData options:0 error:nil];
    
    NSMutableArray* itemTypes = [[NSMutableArray alloc] init];
    
    for(CXMLElement* node in [fieldMapDoc nodesForXPath:@"map/zTypes/typeMap@zType" error:NULL]){
        [itemTypes addObject:[node stringValue]];
    }

    return itemTypes;

}
+(NSArray*) fieldsForItemType:(NSString*) itemType{
    
    NSData* fieldMapData   = [NSData dataWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"typeMap" ofType: @"xml"]];
    
    CXMLDocument* fieldMapDoc = [[CXMLDocument alloc] initWithData:fieldMapData options:0 error:nil];
    
    NSMutableArray* fields = [[NSMutableArray alloc] init];

    for(CXMLNode* node in [fieldMapDoc nodesForXPath:[NSString stringWithFormat:@"/map/zTypes/typeMap[@zType='%@']/field/@value", itemType] error:NULL]){
        [fields addObject:[node stringValue]];
    }
    
    return fields;

}
+(NSArray*) creatorTypesForItemType:(NSString*) itemType{
    NSData* fieldMapData   = [NSData dataWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"typeMap" ofType: @"xml"]];
    
    CXMLDocument* fieldMapDoc = [[CXMLDocument alloc] initWithData:fieldMapData options:0 error:nil];
    
    NSMutableArray* creatorTypes = [[NSMutableArray alloc] init];
    
    for(CXMLNode* node in [fieldMapDoc nodesForXPath:[NSString stringWithFormat:@"map/zTypes/typeMap[@zType='%@']/field/creatorType@value", itemType] error:NULL]){
        [creatorTypes addObject:[node stringValue]];
    }
    
    return creatorTypes;
}

@end
