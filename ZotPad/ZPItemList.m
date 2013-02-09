//
//  ZPItemListViewDataSource.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 7/19/12.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//


#import "ZPItemList.h"

#import "ZPItemDataDownloadManager.h"
#import "ZPItemListViewController.h"
#import "ZPFileViewerViewController.h"

#import "ZPReachability.h"
#import "ZPTableViewUpdater.h"

#define SIZE_OF_TABLEVIEW_UPDATE_BATCH 25
#define SIZE_OF_DATABASE_UPDATE_BATCH 50


@implementation ZPItemList

@synthesize collectionKey = _collectionKey;
@synthesize libraryID =  _libraryID;
@synthesize searchString = _searchString;
@synthesize orderField = _orderField;
@synthesize sortDescending = _sortDescending;
@synthesize itemKeysShown = _itemKeysShown;
@synthesize targetTableView = _tableView;
@synthesize owner;

static ZPItemList* _instance;

+ (ZPItemList*) instance{
    if(_instance == NULL){
        _instance = [[ZPItemList alloc] init];
    }
    return _instance;
}


-(id)init{
    self= [super init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyItemsAvailable:)
                                                 name:ZPNOTIFICATION_ITEMS_AVAILABLE
                                               object:nil];
    
    //Set default sort values
    _orderField = @"dateModified";
    _sortDescending = FALSE;
    _selectedTags = [NSArray array];
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/*
 Called from data layer to notify that there is data for this view and it can be shown
 */

- (void)clearTable{
    
    
    @synchronized(_tableView){
        
        BOOL needsReload = [_tableView numberOfRowsInSection:0]>1;
        
        _itemKeysNotInCache = [NSMutableArray array];
        _itemKeysShown = [NSArray array];
        
        if(needsReload){
            [ZPTableViewUpdater updateTableView:_tableView withContentArray:_itemKeysShown withAnimations:NO];
        }
    }
}

- (void) configureCachedKeys:(NSArray*)array{
    
    @synchronized(_tableView){
        
        _itemKeysShown = array;
        [ZPTableViewUpdater updateTableView:_tableView withContentArray:_itemKeysShown withAnimations:NO];
        
    }
}

-(BOOL) isFullyCached{

    @synchronized(_itemKeysNotInCache){
        return [_itemKeysNotInCache count] == 0;
    }
    
}


- (void) configureServerKeys:(NSArray*)uncachedItems{
    
    //Only update the uncached keys if we are still showing the same item key list
    _itemKeysNotInCache = [NSMutableArray arrayWithArray:uncachedItems];
    [_itemKeysNotInCache removeObjectsInArray:_itemKeysShown];
    
    if([_itemKeysNotInCache count]==0){
        [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ITEM_LIST_FULLY_LOADED object:NULL];
    }
    
    [self updateItemList:FALSE];
    //DDLogVerbose(@"Configured uncached keys");
    
    
}

- (NSArray*) itemKeys{
    @synchronized(_itemKeysNotInCache){
        return [_itemKeysNotInCache arrayByAddingObjectsFromArray:_itemKeysShown];
    }
}

#pragma mark - Receiving data and updating the table view


-(void) updateItemList:(BOOL)animated{
    
    //This can be slightly performance intensive for large libraries, so execute it in background if animated
    
    if(animated && [NSThread isMainThread]){
        [self performSelectorInBackground:@selector(updateItemList:) withObject:[NSNumber numberWithBool:animated]];
    }
    else{
        //Only one thread at a time can make changes in the table
        @synchronized(_tableView){

            //Get a pointer to an array to know if another thread has changed this in the background
            NSArray* thisItemKeys = _itemKeysShown;
            
            
            NSArray* newKeys = [ZPDatabase getItemKeysForLibrary:self.libraryID collectionKey:self.collectionKey
                                                    searchString:[self.searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                                                            tags:_selectedTags
                                                      orderField:self.orderField
                                                  sortDescending:self.sortDescending];
            
            
            //If there is a new set of items loaded, return without performing any updates.
            if(thisItemKeys != _itemKeysShown) return;
            
            @synchronized(_itemKeysNotInCache){
                [_itemKeysNotInCache removeObjectsInArray:newKeys];
            }
            
            //Pad the newKeys with NSNull
            if(_itemKeysNotInCache.count > 0){
                newKeys = [NSMutableArray arrayWithArray:newKeys];
                for(NSInteger i = 0; i < _itemKeysNotInCache.count; ++i){
                    [(NSMutableArray*)newKeys addObject:[NSNull null]];
                }
            }
            [ZPTableViewUpdater updateTableView:_tableView withContentArray:newKeys withAnimations:animated];
        }
    }
}

-(void) _updateRowForItem:(ZPZoteroItem*)item{
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[_itemKeysShown indexOfObject:item.key] inSection:0];
    //Do not reload cell if it is selected
    if(! [[_tableView indexPathForSelectedRow] isEqual:indexPath]){
        [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:_animations];
    }
}


-(void) notifyItemsAvailable:(NSNotification*)notification{
    
    NSArray* items = notification.object;
    
    @synchronized(self){
        
        BOOL found = FALSE;
        BOOL update = FALSE;
        @synchronized(_itemKeysNotInCache){
            if([_itemKeysNotInCache count]>0){
                for(ZPZoteroItem* item in items){
                    if([_itemKeysNotInCache containsObject:item.key]){
                        [_itemKeysNotInCache removeObject:item.key];
                        found=TRUE;
                        if([_itemKeysNotInCache count]==0){
                            [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ITEM_LIST_FULLY_LOADED object:NULL];
                            break;
                        }
                    }
                    
                    
                    //Update the view if we have received sufficient number of new items
                    update = update || ([_itemKeysNotInCache count] % SIZE_OF_DATABASE_UPDATE_BATCH ==0 ||
                                        [_itemKeysShown count] == 0 ||
                                        [_itemKeysShown lastObject]!=[NSNull null]);
                    
                }
            }
        }
        
        
        if(found){
            
            if(update){
                _animations = UITableViewRowAnimationAutomatic;
                [self updateItemList:TRUE];
            }
        }
        /*
         else if([_itemKeysShown containsObject:item.key]){
         //Update the row only if the full citation for this item has changed
         @synchronized(_tableView){
         [self performSelectorOnMainThread:@selector(_updateRowForItem:) withObject:item waitUntilDone:YES];
         }
         }
         */
    }
}
/*
 - (void) _refreshCellAtIndexPaths:(NSArray*)indexPaths{
 [_tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];
 
 }
 */



#pragma mark - ZPTagOwner protocol

-(void) selectTag:(NSString*)tag{
    _selectedTags = [[_selectedTags arrayByAddingObject:tag] sortedArrayUsingSelector:@selector(compare:)];
    
    // Update the selection
    // (TODO: Figure out a more clean way to do this.)
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        UISplitViewController* root =  (UISplitViewController*) [UIApplication sharedApplication].delegate.window.rootViewController;
        [(ZPItemListViewController *)[[root.viewControllers lastObject] topViewController] configureView];
    }
}
-(void) deselectTag:(NSString*)tag{
    NSMutableArray* temp = [NSMutableArray arrayWithArray:_selectedTags];
    [temp removeObject:tag];
    _selectedTags = temp;
    
    // Update the selection
    // (TODO: Figure out a more clean way to do this.)
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        UISplitViewController* root =  (UISplitViewController*) [UIApplication sharedApplication].delegate.window.rootViewController;
        [(ZPItemListViewController *)[[root.viewControllers lastObject] topViewController] configureView];
    }
    
}

-(NSArray*) tags{
    return _selectedTags;
}

-(NSArray*) availableTags{
    //Get the tags for currently visible items
    return [ZPDatabase tagsForItemKeys:_itemKeysShown];
}

-(BOOL) isTagSelected:(NSString*)tag{
    return [_selectedTags containsObject:tag];
}

@end
