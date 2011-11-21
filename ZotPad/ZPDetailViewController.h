//
//  ZPDetailViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ZPDetailViewController : UIViewController <UISplitViewControllerDelegate, UITableViewDataSource, UITableViewDelegate>{
    NSString* _searchString;
    NSInteger _collectionID;
    NSInteger _libraryID;
    NSString* _sortField;
    BOOL _sortIsDescending;
    
    NSArray* _itemIDsShown;
  
    UITableView* itemTableView;
    NSMutableDictionary* _cellCache;
}

- (void)configureView;

@property (nonatomic, retain) IBOutlet UITableView* itemTableView;

@property NSInteger collectionID;
@property NSInteger libraryID;

@property (copy) NSString* searchString;

@property (copy) NSString* sortField;
@property BOOL sortIsDescending;



@end
