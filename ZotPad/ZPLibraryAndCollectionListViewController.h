//
//  ZPLibraryAndCollectionViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZPItemListViewController.h"



@class ZPItemListViewController;

@interface ZPLibraryAndCollectionListViewController : UITableViewController{
    NSArray* _content;
    NSInteger _currentlibraryID;
    NSString* _currentCollectionKey;
    UIActivityIndicatorView* _activityIndicator;
}

@property (strong, nonatomic) ZPItemListViewController *detailViewController;
@property (assign) NSInteger currentlibraryID;
@property (retain, nonatomic) NSString* currentCollectionKey;
@property (assign) NSInteger drilledCollectionIndex;
@property (assign) NSInteger selectedCollectionIndex;

@end
