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
#import "ZPLibraryObserver.h"

@class ZPDetailedItemListViewController;

@interface ZPLibraryAndCollectionListViewController : UITableViewController <ZPLibraryObserver>{
    ZPDataLayer* _database;
    NSArray* _content;
    NSInteger _currentLibraryID;
    NSString* _currentCollectionKey;
}
@property (strong, nonatomic) ZPDetailedItemListViewController *detailViewController;
@property NSInteger currentLibraryID;
@property (retain, nonatomic) NSString* currentCollectionKey;

+ (ZPLibraryAndCollectionListViewController*) instance;

@end
