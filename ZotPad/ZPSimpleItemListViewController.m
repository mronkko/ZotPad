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
#import "ZPItemDetailViewController.h"
#import "ZPLogger.h"


#define SIZE_OF_TABLEVIEW_UPDATE_BATCH 25
#define SIZE_OF_DATABASE_UPDATE_BATCH 50

@interface ZPSimpleItemListViewController();

-(void) _updateRowForItem:(ZPZoteroItem*)item;
-(void) _performRowInsertions:(NSArray*)insertIndexPaths reloads:(NSArray*)reloadIndexPaths tableLength:(NSNumber*)tableLength;

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
    
    [_cellCache removeAllObjects];
}


-(void) notifyItemAvailable:(ZPZoteroItem *)item{

    NSLog(@"Received item %@",item.fullCitation);

    @synchronized(self){

        BOOL found = FALSE;
        BOOL update = FALSE;
        @synchronized(_itemKeysNotInCache){
            if([_itemKeysNotInCache containsObject:item.key]){
                [_itemKeysNotInCache removeObject:item.key];
                found=TRUE;
            }
//            NSLog(@"Item keys not in cache deacreased to %i after removing key %@",[_itemKeysNotInCache count],item.key);
            
            //Update the view if we have received sufficient number of new items
            update = ([_itemKeysNotInCache count] % SIZE_OF_DATABASE_UPDATE_BATCH ==0 ||
               [_itemKeysShown count] == 0 ||
                      [_itemKeysShown lastObject]!=[NSNull null]);
        
        }
        
        
        if(found){
            
            if(update){  
                _animations = UITableViewRowAnimationAutomatic;
                [self _performTableUpdates:TRUE];
            }
        }
        else if([_itemKeysShown containsObject:item.key]){
            //Update the row only if the full citation for this item has changed 
            @synchronized(_tableView){
                [self performSelectorOnMainThread:@selector(_updateRowForItem:) withObject:item waitUntilDone:YES];
            }
        }
    }    
}

-(void) _performTableUpdates:(BOOL)animated{
    
    NSLog(@"Start table updates");
    //Only one thread at a time
    @synchronized(self){
        //Get a pointer to an array to know if another thread has changed this in the background
        NSArray* thisItemKeys = _itemKeysShown;
        
        //Copy the array to be safe from accessing it using multiple threads
        NSMutableArray* newItemKeysShown = [NSMutableArray arrayWithArray:_itemKeysShown];

        NSArray* newKeys = [[ZPDataLayer instance] getItemKeysFromCacheForLibrary:self.libraryID collection:self.collectionKey
                                                                     searchString:[self.searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]orderField:self.orderField sortDescending:self.sortDescending];
        

        //If there is a new set of items loaded, return without performing any updates. 
        if(thisItemKeys != _itemKeysShown || _invalidated) return;

        NSLog(@"Beging updating the table rows: Known keys befor update %i. Unknown keys %i. New keys %i",[_itemKeysShown count],[_itemKeysNotInCache count],[newKeys count]);

        @synchronized(_itemKeysNotInCache){
            [_itemKeysNotInCache removeObjectsInArray:newKeys];
        }

        NSInteger index=0;
        NSMutableArray* reloadIndices = [NSMutableArray array];
        NSMutableArray* insertIndices = [NSMutableArray array];
        
        for(NSString* newKey in newKeys){
            //If there is a new set of items loaded, return without performing any updates. 
            if(thisItemKeys != _itemKeysShown || _invalidated ) return;
            
            //First index contains a placeholder cell
            
            if([newItemKeysShown count] == index){
               // NSLog(@"Adding item %@ at %i",newKey,index);
                [newItemKeysShown addObject:newKey];
                if(index==0) [reloadIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                else [insertIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
            }
            else if([newItemKeysShown objectAtIndex:index] == [NSNull null]){
               // NSLog(@"Replacing NULL with %@ at %i",newKey,index);
                [newItemKeysShown replaceObjectAtIndex:index withObject:newKey];
                [reloadIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
            }
            
            //There is something in the way, so we need to either insert or move
            else if(![newKey isEqualToString:[newItemKeysShown objectAtIndex:index]]){
                
                //We found that a shown key does not match the data on server
                
                NSInteger oldIndex = [newItemKeysShown indexOfObject:newKey];
                
                //If the new data cannot be found in the view, insert it
                if(oldIndex==NSNotFound){
                 //   NSLog(@"Inserting %@ at %i",newKey,index);
                    [newItemKeysShown insertObject:newKey atIndex:index];
                    [insertIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                }
                //Else move it
                else{
                   // NSLog(@"Moving %@ from %i to %i",newKey,oldIndex,index);

                    //Instead of performing a move operation, we are just replacing the old location with null. This because of thread safety.
                    
                    [newItemKeysShown replaceObjectAtIndex:oldIndex withObject:[NSNull null]];
                    [newItemKeysShown insertObject:newKey atIndex:index];
                    [insertIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                    [reloadIndices addObject:[NSIndexPath indexPathForRow:oldIndex inSection:0]];
                }
            }
            index++;
        }
        
        //Add empty rows to the end if there are still unknown rows
        @synchronized(_itemKeysNotInCache){
            while([newItemKeysShown count]<([_itemKeysNotInCache count] + [newKeys count])){
                //            NSLog(@"Padding with null %i (Unknown keys: %i, Known keys: %i)",[newItemKeysShown count],[_itemKeysNotInCache count],[newKeys count]);
                if([newItemKeysShown count]==0)
                    [reloadIndices addObject:[NSIndexPath indexPathForRow:0 inSection:0]];
                else{
                    [insertIndices addObject:[NSIndexPath indexPathForRow:[newItemKeysShown count] inSection:0]];
                }
                [newItemKeysShown addObject:[NSNull null]];
            }
        }
        
        @synchronized(_tableView){

            if(thisItemKeys != _itemKeysShown || _invalidated) return;
            
            _itemKeysShown = newItemKeysShown;

            NSNumber* tableLength = [NSNumber numberWithInt:[_itemKeysNotInCache count] + [newKeys count]];
            NSLog(@"Items found from DB %i, items that are still uncached %i",[newKeys count],[_itemKeysNotInCache count]);
            if(animated){
                SEL selector = @selector(_performRowInsertions:reloads:tableLength:);
                NSMethodSignature* signature = [[self class] instanceMethodSignatureForSelector:selector];
                NSInvocation* invocation  = [NSInvocation invocationWithMethodSignature:signature];
                [invocation setTarget:self];
                [invocation setSelector:selector];
                
                //Set arguments
                [invocation setArgument:&insertIndices atIndex:2];
                [invocation setArgument:&reloadIndices atIndex:3];
                [invocation setArgument:&tableLength atIndex:4];
                
                
                [invocation performSelectorOnMainThread:@selector(invoke) withObject:NULL waitUntilDone:YES];
            }
            else{
                if([tableLength intValue]>[_itemKeysShown count]){
                    _itemKeysShown = [_itemKeysShown subarrayWithRange:NSMakeRange(0,[tableLength intValue])];
                }
                [_tableView performSelectorOnMainThread:@selector(reloadData) withObject:NULL waitUntilDone:YES];
            }
            NSLog(@"End updating the table rows");
            
            if([_itemKeysNotInCache count] == 0){
                [_activityIndicator stopAnimating];   
            }
            
        }
    }
}


-(void) _performRowInsertions:(NSArray*)insertIndexPaths reloads:(NSArray*)reloadIndexPaths tableLength:(NSNumber*)tableLength{
    NSLog(@"Modifying the table. Inserts %i Reloads %i, Max length %@, Item key array length %i",[insertIndexPaths count],[reloadIndexPaths count],tableLength,[_itemKeysShown count]);
//    [_tableView beginUpdates];
    NSLog(@"Insert index paths %@",insertIndexPaths);
    if([insertIndexPaths count]>0) [_tableView insertRowsAtIndexPaths:insertIndexPaths withRowAnimation:_animations];
    NSLog(@"Reload index paths %@",reloadIndexPaths);
    if([reloadIndexPaths count]>0) [_tableView reloadRowsAtIndexPaths:reloadIndexPaths withRowAnimation:_animations];

    if([tableLength intValue]<[_itemKeysShown count]){
        NSMutableArray* deleteIndexPaths = [NSMutableArray array];
        
        NSInteger max = [_itemKeysShown count];
        for(NSInteger i=[tableLength intValue];i<max;i++){
            [deleteIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
        }
        
        _itemKeysShown = [_itemKeysShown subarrayWithRange:NSMakeRange(0,[tableLength intValue])];
        NSLog(@"Delete index paths %@",deleteIndexPaths);
        NSLog(@"Deletes %i",[deleteIndexPaths count]);
        
        [_tableView deleteRowsAtIndexPaths:deleteIndexPaths withRowAnimation:_animations];
    }

//    [_tableView endUpdates];
}
-(void) _updateRowForItem:(ZPZoteroItem*)item{
    [_cellCache removeObjectForKey:item.key];
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[_itemKeysShown indexOfObject:item.key] inSection:0];
    //Do not reload cell if it is selected
    if(! [[_tableView indexPathForSelectedRow] isEqual:indexPath]) [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:_animations];
}

#pragma mark -
#pragma mark UITableViewDataSource Protocol Methods

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rows=MAX(1,[_itemKeysShown count]);
    NSLog(@"Number of rows is now %i",rows);
    return rows;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}



- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //If the data has become invalid, return a cell 
    NSArray* tempArray = _itemKeysShown;
    if(indexPath.row>=[tempArray count]) return [tableView dequeueReusableCellWithIdentifier:@"BlankCell"];
    
    
    NSObject* keyObj = [tempArray objectAtIndex: indexPath.row];
    
    
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
        if(![key isEqualToString:@""]) item = [ZPZoteroItem retrieveOrInitializeWithKey:key];
        
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
                if(item.date != 0){
                    authorsLabel.text = [NSString stringWithFormat:@"%@ (%i)",item.creatorSummary,item.date];
                }
                else{
                    authorsLabel.text = [NSString stringWithFormat:@"%@ (No date)",item.creatorSummary];
                }
            }    
            else if(item.date != 0){
                authorsLabel.text = [NSString stringWithFormat:@"No author (%i)",item.date];
            }
            else{
                authorsLabel.text = @"No author (No date)";
            }
            
            
        }
        [_cellCache setObject:cell forKey:key];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Get the key for the selected item 
    if(indexPath.row < [_itemKeysShown count]){
        NSString* currentItemKey = [_itemKeysShown objectAtIndex: indexPath.row]; 
        
        if(currentItemKey != [NSNull null]){
            [[ZPItemDetailViewController instance] setSelectedItem:[ZPZoteroItem retrieveOrInitializeWithKey:currentItemKey]];
            [[ZPItemDetailViewController instance] configure];
            
        }
    }
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
        
    [super viewDidLoad];
    
    //Set up activity indicator. 
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0,0,20, 20)];
    [_activityIndicator hidesWhenStopped];
    UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
    self.navigationItem.rightBarButtonItem = barButton;

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
    @synchronized(_itemKeysNotInCache){
        //If there are more items coming, make this active
        if([_itemKeysNotInCache count] >0){
            [_activityIndicator startAnimating];
        }
        else{
            [_activityIndicator stopAnimating];
        }
    }
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
