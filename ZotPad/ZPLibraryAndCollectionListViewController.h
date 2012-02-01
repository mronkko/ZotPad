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
    NSNumber* _currentlibraryID;
    NSString* _currentCollectionKey;
    UIActivityIndicatorView* _activityIndicator;
    
}

@property (strong, nonatomic) ZPDetailedItemListViewController *detailViewController;
@property (retain, nonatomic) NSNumber* currentlibraryID;
@property (retain, nonatomic) NSString* currentCollectionKey;

// TODO: refactor the code so that this does not need a singleton

+ (ZPLibraryAndCollectionListViewController*) instance;

@end
