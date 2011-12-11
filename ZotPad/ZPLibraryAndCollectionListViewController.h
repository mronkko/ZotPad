//
//  ZPLibraryAndCollectionViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZPDetailedItemListViewController.h"
#import "ZPDataLayer.h"

@class ZPDetailedItemListViewController;

@interface ZPLibraryAndCollectionListViewController : UITableViewController{
    ZPDataLayer* _database;
    NSArray* _content;
    NSInteger _currentLibrary;
    NSInteger _currentCollection;
}
@property (strong, nonatomic) ZPDetailedItemListViewController *detailViewController;
@property NSInteger currentLibrary;
@property NSInteger currentCollection;

+ (ZPLibraryAndCollectionListViewController*) instance;
- (void)notifyDataAvailable;

@end
