//
//  ZPTableViewUpdater.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 1/15/13.
//
//

#import <Foundation/Foundation.h>

@interface ZPTableViewUpdater : NSObject

+(void) updateTableView:(UITableView*) tableView withContentArray:(NSArray*)contentArray withAnimations:(BOOL)animated;
    
@end
