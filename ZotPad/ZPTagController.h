//
//  ZPTagController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 9/13/12.
//
//

#import <Foundation/Foundation.h>

@interface ZPTagController : NSObject <UITableViewDataSource>{
    NSArray* _tags;
    NSInteger _estimatedNumberOfRows;
    NSInteger _nextTagIndex;
}

-(void) configure;

@end
