//
//  ZPItemListDataSource.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 1/15/13.
//
//

#import <Foundation/Foundation.h>

@interface ZPItemListDataSource : NSObject <UITableViewDataSource>

@property (nonatomic, retain) NSArray* contentArray;

@end
