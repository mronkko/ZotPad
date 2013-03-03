//
//  ZPItemListViewDataSource.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 7/19/12.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPCore.h"
#import "ZPTagOwner.h"
#import "ZPItemListDataSource.h"

@interface ZPItemList : NSObject <UITableViewDataSource, ZPTagOwner>{
 
    //This is an array instead of a mutable array because of thread safety
    NSArray* _itemKeysShown;
    NSMutableArray* _itemKeysNotInCache;
    
    NSString* _searchString;
    NSString* _collectionKey;
    NSInteger _libraryID;
    NSString* _orderField;
    BOOL _sortDescending;
    
    NSInteger _animations;
    BOOL _hasContent;
    
    UITableView* _tableView;
    
    ZPZoteroAttachment* _attachmentInQuicklook;
    
    NSArray* _selectedTags;
}

+ (ZPItemList*) instance;

//This is the tableview that the datasource targets.
@property (nonatomic, retain) UITableView* targetTableView;

@property (nonatomic, retain) NSArray* itemKeysShown;
@property (nonatomic, retain) NSString* collectionKey;
@property (assign) NSInteger libraryID;
@property (nonatomic, retain) NSString* searchString;
@property (nonatomic, retain) NSString* orderField;
@property (assign) BOOL sortDescending;
@property (nonatomic, retain) UIViewController* owner;

- (NSArray*) itemKeys;

- (void)clearTable;
- (void)configureCachedKeys:(NSArray*)array;
- (void)configureServerKeys:(NSArray*)uncachedItems;

-(void) _updateRowForItem:(ZPZoteroItem*)item;
-(void) updateItemList:(BOOL)animated;

-(BOOL) isTagSelected:(NSString*)tag;
-(BOOL) isFullyCached;

@end
