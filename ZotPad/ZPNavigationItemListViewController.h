//
//  ZPNavigationItemListViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/4/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ZPNavigationItemListViewController : UITableViewController{
    NSCache* _cellCache;
    NSArray* _itemKeysShown;
}

// This class is used as a singleton
+ (ZPNavigationItemListViewController*) instance;

- (void)notifyItemAvailable:(NSString*) key;
- (void)_refreshCellAtIndexPaths:(NSArray*)indexPath;

@end
