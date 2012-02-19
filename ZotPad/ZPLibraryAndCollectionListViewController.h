//
//  ZPLibraryAndCollectionViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZPItemListViewController.h"
#import "ZPDataLayer.h"
#import "ZPLibraryObserver.h"

@class ZPItemListViewController;

@interface ZPLibraryAndCollectionListViewController : UITableViewController <ZPLibraryObserver>{
    ZPDataLayer* _database;
    NSArray* _content;
    NSNumber* _currentlibraryID;
    NSString* _currentCollectionKey;
    UIActivityIndicatorView* _activityIndicator;
    
}

@property (strong, nonatomic) ZPItemListViewController *detailViewController;
@property (retain, nonatomic) NSNumber* currentlibraryID;
@property (retain, nonatomic) NSString* currentCollectionKey;


@end
