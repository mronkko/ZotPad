//
//  ZPNavigationItemListViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/4/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPSimpleItemListViewController.h"
#import "ZPZoteroItem.h"
#import "ZPDataLayer.h"

#import "ZPLogger.h"


#define SIZE_OF_TABLEVIEW_UPDATE_BATCH 5
#define SIZE_OF_DATABASE_UPDATE_BATCH 25

@interface ZPSimpleItemListViewController();
-(void) _updateRowForItem:(ZPZoteroItem*)item;
-(void) _performRowReloads:(NSArray*)indexPaths;
-(void) _performRowInsertions:(NSArray*)indexPaths;
-(void) _performRowDeletions:(NSArray*)indexPaths;
-(void) _performRowMoveFromFirstIndexToSecond:(NSArray*)indexPaths;

@end


@implementation ZPSimpleItemListViewController


@synthesize itemKeysShown = _itemKeysShown;
@synthesize tableView = _tableView;

@synthesize collectionKey = _collectionKey;
@synthesize libraryID =  _libraryID;
@synthesize searchString = _searchString;
@synthesize orderField = _orderField;
@synthesize sortDescending = _sortDescending;


#pragma mark - Managing the detail item

-(id) init{
    self = [super init];
    _cellCache = [[NSCache alloc] init];
    _animations = UITableViewRowAnimationNone;
    return self;
}

- (void)configureWithItemListController:(ZPSimpleItemListViewController*)controller{
 
    _itemKeysShown = controller->_itemKeysShown;
    _itemKeysNotInCache = controller->_itemKeysNotInCache;
    _searchString = controller->_searchString;
    _collectionKey = controller->_collectionKey;
    _libraryID = controller->_libraryID;
    _orderField = controller->_orderField;
    _sortDescending = controller->_sortDescending;

    [[ZPDataLayer instance] registerItemObserver:self];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}


-(void) notifyItemAvailable:(ZPZoteroItem *)item{

    @synchronized(self){
        
        if([_itemKeysNotInCache indexOfObject:item.key]){
            [_itemKeysNotInCache removeObject:item.key];
            
            NSLog(@"Item keys not in cache deacreased to %i after removing key %@",[_itemKeysNotInCache count],item.key);
            
            //Update the view if we have received sufficient number of new items
            if([_itemKeysNotInCache count] % SIZE_OF_DATABASE_UPDATE_BATCH ==0 ||
               [_itemKeysShown count] == 0 ||
               [_itemKeysShown lastObject]!=[NSNull null]){
               
                _animations = UITableViewRowAnimationAutomatic;
                [self _performTableUpdates];
            }
        }
        else if([_itemKeysShown indexOfObject:item.key]){
            //Update the row only if the full citation for this item has changed 
            [self performSelectorOnMainThread:@selector(_updateRowForItem:) withObject:item waitUntilDone:YES];
        }
    }    
}

-(void) _performTableUpdates{
    
    NSMutableArray* thisItemKeys = _itemKeysShown;
    
    NSArray* newKeys = [[ZPDataLayer instance] getItemKeysFromCacheForLibrary:self.libraryID collection:self.collectionKey
                                                                 searchString:[self.searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]orderField:self.orderField sortDescending:self.sortDescending];
    
    
    [_itemKeysNotInCache removeObjectsInArray:newKeys];
    
    NSLog(@"Beging updating the table rows");
    
    NSInteger index=0;
    NSMutableArray* reloadIndices = [NSMutableArray array];
    NSMutableArray* insertIndices = [NSMutableArray array];
    
    for(NSString* newKey in newKeys){

        //If there is a new set of items loaded, return without performing any updates. 
        if(thisItemKeys != _itemKeysShown) return;
        
        if([thisItemKeys count] == index){
            NSLog(@"Adding item %@ at %i",newKey,index);
            [thisItemKeys addObject:newKey];
            [insertIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
        }
        else if([thisItemKeys objectAtIndex:index] == [NSNull null]){
            NSLog(@"Replacing NULL with %@ at %i",newKey,index);
            [thisItemKeys replaceObjectAtIndex:index withObject:newKey];
            [reloadIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
        }
        //There is something in the way, so we need to either insert or move
        else if(![newKey isEqualToString:[thisItemKeys objectAtIndex:index]]){
            
            //We found that a shown key does not match the data on server
            
            NSInteger oldIndex = [thisItemKeys indexOfObject:newKey];
            
            //If the new data cannot be found in the view, insert it
            if(oldIndex==NSNotFound){
                NSLog(@"Inserting %@ at %i",newKey,index);
                [thisItemKeys insertObject:newKey atIndex:index];
                [insertIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
            }
            //Else move it
            else{
                //Before movign we need to do all the other table operations
                if([insertIndices count]>0) {
                    [self performSelectorOnMainThread:@selector(_performRowInsertions:) withObject:insertIndices waitUntilDone:TRUE];
                    [insertIndices removeAllObjects];
                }
                if([reloadIndices count]>0){
                    [self performSelectorOnMainThread:@selector(_performRowReloads:) withObject:reloadIndices waitUntilDone:TRUE];
                    [reloadIndices removeAllObjects];
                }
                
                [thisItemKeys removeObjectAtIndex:oldIndex];
                [thisItemKeys insertObject:newKey atIndex:index];
                NSArray* paramArray = [NSArray arrayWithObjects:[NSIndexPath indexPathForRow:oldIndex inSection:0],[NSIndexPath indexPathForRow:index inSection:0],nil];
                [self performSelectorOnMainThread:@selector(_performRowMoveFromFirstIndexToSecond:) withObject:paramArray waitUntilDone:TRUE];
                
            }
        }
        index++;
    }
    
    //Add empty rows to the end if there are still unknown rows
    while([thisItemKeys count]<([_itemKeysNotInCache count] + [newKeys count])){
        NSLog(@"Padding with null %i (Unknown keys: %i, Known keys: %i)",[thisItemKeys count],[_itemKeysNotInCache count],[newKeys count]);
        [insertIndices addObject:[NSIndexPath indexPathForRow:[thisItemKeys count] inSection:0]];
        [thisItemKeys addObject:[NSNull null]];
    }
    
    if([insertIndices count]>0) [self performSelectorOnMainThread:@selector(_performRowInsertions:) withObject:insertIndices waitUntilDone:TRUE];
    
    
    if([reloadIndices count]>0) [self performSelectorOnMainThread:@selector(_performRowReloads:) withObject:reloadIndices waitUntilDone:TRUE];
    
    //If modifications have caused the visible items become too long, remove items from the end
    NSMutableArray* deleteIndices = [NSMutableArray array];   
    while([thisItemKeys count]>([_itemKeysNotInCache count] + [newKeys count])){
        NSLog(@"Removing extra from end %i (Unknown keys: %i, Known keys: %i)",[thisItemKeys count],[_itemKeysNotInCache count],[newKeys count]);
        [thisItemKeys removeLastObject];
        [deleteIndices addObject:[NSIndexPath indexPathForRow:[thisItemKeys count] inSection:0]];
    }
    if([deleteIndices count] >0) [self performSelectorOnMainThread:@selector(_performRowDeletions:) withObject:deleteIndices waitUntilDone:YES];
    
    NSLog(@"End updating the table rows");
}

-(void) _performRowReloads:(NSArray*)indexPaths{
    [_tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:_animations];
}
-(void) _performRowInsertions:(NSArray*)indexPaths{
    [_tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:_animations];
}
-(void) _performRowDeletions:(NSArray*)indexPaths{
    [_tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:_animations];
}
-(void) _performRowMoveFromFirstIndexToSecond:(NSArray*)indexPaths{
    [_tableView moveRowAtIndexPath:[indexPaths objectAtIndex:0] toIndexPath:[indexPaths objectAtIndex:1]];
} 

-(void) _updateRowForItem:(ZPZoteroItem*)item{
    [_cellCache removeObjectForKey:item.key];
    [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:[_itemKeysShown indexOfObject:item.key] inSection:0]] withRowAnimation:_animations];

}

#pragma mark -
#pragma mark UITableViewDataSource Protocol Methods

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    return [_itemKeysShown count];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}



- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    
    
    NSObject* keyObj = [_itemKeysShown objectAtIndex: indexPath.row];
    
    
    NSString* key;
    if(keyObj==[NSNull null]){
        key=@"";
    }    
    else{
        key= (NSString*) keyObj;
    }    
    
	UITableViewCell* cell = [_cellCache objectForKey:key];
    
    if(cell==nil){
        
        
        ZPZoteroItem* item=NULL;
        if(![key isEqualToString:@""]) item = [[ZPDataLayer instance] getItemByKey:key];
        
        if(item==NULL){
            cell = [tableView dequeueReusableCellWithIdentifier:@"LoadingCell"];        
        }
        else{
            
            cell = [tableView dequeueReusableCellWithIdentifier:@"ZoteroItemCell"];
            
            UILabel *titleLabel = (UILabel *)[cell viewWithTag:1];
            titleLabel.text = item.title;
            
            UILabel *authorsLabel = (UILabel *)[cell viewWithTag:2];
            
            //Show different things depending on what data we have
        
            if(item.creatorSummary!=NULL){
                if(item.year != 0){
                    authorsLabel.text = [NSString stringWithFormat:@"%@ (%i)",item.creatorSummary,item.year];
                }
                else{
                    authorsLabel.text = [NSString stringWithFormat:@"%@ (No date)",item.creatorSummary];
                }
            }    
            else if(item.year != 0){
                authorsLabel.text = [NSString stringWithFormat:@"No author (%i)",item.year];
            }
            else{
                authorsLabel.text = @"No author (No date)";
            }
            
            
        }
        [_cellCache setObject:cell forKey:key];
    }
    
    return cell;
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
        
    [super viewDidLoad];

}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
    [[ZPDataLayer instance] removeItemObserver:self];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

@end
