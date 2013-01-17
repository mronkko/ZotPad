//
//  ZPMasterItemListViewController.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 7/19/12.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZPItemList.h"
#import "ZPItemDetailViewController.h"
#import "ZPItemListDataSource.h"

@interface ZPMasterItemListViewController : UITableViewController{
    ZPItemListDataSource* _dataSource;

}

@property (retain) ZPItemDetailViewController* detailViewController;

@end
