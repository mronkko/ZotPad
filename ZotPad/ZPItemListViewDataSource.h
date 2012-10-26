//
//  ZPItemListViewDataSource.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 7/19/12.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPCore.h"
#import "ZPPreviewSource.h"

@interface ZPItemListViewDataSource : NSObject <UITableViewDataSource, ZPPreviewSource>{
 
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
    BOOL _invalidated;
    
    UITableView* _tableView;
    
    ZPZoteroAttachment* _attachmentInQuicklook;
    
    NSArray* _selectedTags;
}

+ (ZPItemListViewDataSource*) instance;

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
-(void) _performRowInsertions:(NSArray*)insertIndexPaths reloads:(NSArray*)reloadIndexPaths tableLength:(NSInteger)tableLength;
-(void) _performTableUpdates:(BOOL)animated;
//-(void) _refreshCellAtIndexPaths:(NSArray*)indexPath;

-(void) selectTag:(NSString*)tag;
-(void) deselectTag:(NSString*)tag;
-(BOOL) isTagSelected:(NSString*)tag;
-(NSArray*) selectedTags;

@end
