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

#define DEBUG_ITEM_LIST 1

#define SIZE_OF_TABLEVIEW_UPDATE_BATCH 5

@interface ZPSimpleItemListViewController ();

-(void) updateTableViewWithUpdatedItemKeyArray;

@end

@implementation ZPSimpleItemListViewController

@synthesize itemKeysShown = _itemKeysShown;
//@synthesize itemKeysFromServer = _itemKeysFromServer;
@synthesize tableView = _tableView;

#pragma mark - Managing the detail item

-(id) init{
    self = [super init];
    _cellCache = [[NSCache alloc] init];

    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    return [_itemKeysShown count];
}

-(void) setItemKeysShownArray:(NSMutableArray*)itemKeysShown itemKeysFromServerArray:(NSArray*)itemKeysFromServer{
    _itemKeysShown = itemKeysShown;
    _itemKeysFromServer = itemKeysFromServer;
    _itemKeysFromServerIndex = 0;
}


/*
 
 No longer needed. Do not delete yet, because this might come usefull later
 
// Tells an observer that basic citation information is available for items
-(void) notifyItemBasicsAvailable:(ZPZoteroItem*) item{
    
    
    NSEnumerator *e = [[self.tableView indexPathsForVisibleRows] objectEnumerator];
    
    NSIndexPath* indexPath;
    while ((indexPath = (NSIndexPath*) [e nextObject]) && indexPath.row <=[_itemKeysShown count]) {
        if([item.key isEqualToString:[_itemKeysShown objectAtIndex:indexPath.row]]){
            
            //Tell this cell to update because it just got data
            
            [self performSelectorOnMainThread:@selector(_refreshCellAtIndexPaths:) withObject:[NSArray arrayWithObject:indexPath] waitUntilDone:NO];
            
            break;
        }
    }
}
*/

/*
 
 When this is called, cache just got some data that we might want to be interested in.

 We assume that the data are only added to the itemKeyArray and never removed.
 
 */

-(void) notifyItemKeyArrayUpdated:(NSArray*)itemKeyArray{
    
    
    if(_itemKeysFromServer == itemKeyArray){
        
        @synchronized(self){

            while(_itemKeysFromServerIndex < [_itemKeysFromServer count] && [_itemKeysFromServer objectAtIndex:_itemKeysFromServerIndex] !=[NSNull null]){
                [self performSelectorOnMainThread:@selector(updateTableViewWithUpdatedItemKeyArray) withObject:NULL waitUntilDone:TRUE];

                //TODO: Figure out a better way for the following hack
                //Since we will be executing a lot of code in the main thread to update the UI, do a small delay to prevent
                //the UI from becoming jerky
                
                [NSThread sleepForTimeInterval:.2];
            }
        }
       
    }
}

/*
 
 This does a maximum of five updates to table view and returns.

 */

-(void) updateTableViewWithUpdatedItemKeyArray{
    
    if(DEBUG_ITEM_LIST) NSLog(@"*******************    BEGIN TABLE UPDATES **************************");
    
    NSInteger counter=0;
    
    while(counter < SIZE_OF_TABLEVIEW_UPDATE_BATCH && 
          _itemKeysFromServerIndex<[_itemKeysFromServer count]){
        
        NSObject* keyFromServer=[_itemKeysFromServer objectAtIndex:_itemKeysFromServerIndex];
        
        //The server array is padded with nulls, so do not iterate over these.
        if(keyFromServer == [NSNull null]){
            break;
        }
                
        if([_itemKeysShown count]<=_itemKeysFromServerIndex){
            if(DEBUG_ITEM_LIST) NSLog(@"Adding %@",keyFromServer);
            [_itemKeysShown addObject:keyFromServer]; 
            [_tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:[_itemKeysShown count]-1 inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
            counter++;
        }
        else if([_itemKeysShown objectAtIndex:_itemKeysFromServerIndex] == [NSNull null]){
            if(DEBUG_ITEM_LIST) NSLog(@"Replacing NULL with %@ at %i",keyFromServer,_itemKeysFromServerIndex);
            [_itemKeysShown replaceObjectAtIndex:_itemKeysFromServerIndex withObject:keyFromServer];
            [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:_itemKeysFromServerIndex inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
            counter++;
        }
        //There is something in the way, so we need to either insert or move
        else if(![(NSString*)keyFromServer isEqualToString:[_itemKeysShown objectAtIndex:_itemKeysFromServerIndex]]){
            //We found that a shown key does not match the data on server
            
            NSInteger index = [_itemKeysShown indexOfObject:keyFromServer];
            
            //If the new data cannot be found in the view, insert it
            if(index==NSNotFound){
                if(DEBUG_ITEM_LIST) NSLog(@"Inserting %@ at %i",keyFromServer,_itemKeysFromServerIndex);
                [_itemKeysShown insertObject:keyFromServer atIndex:_itemKeysFromServerIndex];
                [_tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:_itemKeysFromServerIndex inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                counter++;
                
            }
            //Else move it
            else{
                if(DEBUG_ITEM_LIST){
                    ZPZoteroItem* item = [ZPZoteroItem ZPZoteroItemWithKey:(NSString*)keyFromServer];
                    NSLog(@"Moving %@ from %i to %i (Timstamp %@)",keyFromServer,index,_itemKeysFromServerIndex,item.lastTimestamp);
                }
                [_itemKeysShown removeObjectAtIndex:index];
                [_itemKeysShown insertObject:keyFromServer atIndex:_itemKeysFromServerIndex];
                [_tableView moveRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0] toIndexPath:[NSIndexPath indexPathForRow:_itemKeysFromServerIndex inSection:0] ];
                counter++;
            }
        }
        
        //If modifications have caused the visible items become too long, remove items from the end
        
        while([_itemKeysFromServer count]<[_itemKeysShown count]){
            if(DEBUG_ITEM_LIST) NSLog(@"Removing extra from end");
            [_itemKeysShown removeLastObject];
            [_tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:[_itemKeysShown count] inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
        }

        _itemKeysFromServerIndex++;
    }
    
    //Finally, if the number of objects on the server is longer than the number in this view, add placeholder cells
    
    if([_itemKeysFromServer count]>[_itemKeysShown count]){
        if(DEBUG_ITEM_LIST) NSLog(@"Padding, rows were %i (%@)",[_itemKeysShown count]);
        NSMutableArray* paddingArray = [NSMutableArray arrayWithCapacity:[_itemKeysFromServer count]-[_itemKeysShown count]];
        
        while([_itemKeysFromServer count]>[_itemKeysShown count]){
            [_itemKeysShown addObject:[NSNull null]];
            [paddingArray addObject:[NSIndexPath indexPathForRow:[_itemKeysShown count]-1 inSection:0]];
        }
        [_tableView insertRowsAtIndexPaths:paddingArray withRowAnimation:UITableViewRowAnimationAutomatic];
    }
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
            
            //if(DEBUG_ITEM_LIST) NSLog(@"Not in cache, creating");
            cell = [tableView dequeueReusableCellWithIdentifier:@"ZoteroItemCell"];
            
            UILabel *titleLabel = (UILabel *)[cell viewWithTag:1];
            titleLabel.text = item.title;
            
            UILabel *authorsLabel = (UILabel *)[cell viewWithTag:2];
            
            //Show different things depending on what data we have
        
            NSString* debugString=@"";

            if(DEBUG_ITEM_LIST){
                debugString=[NSString stringWithFormat:@"Row: %i Key: %@ TS: %@ ",indexPath.row,key,item.lastTimestamp];
            }
            
            if(item.creatorSummary!=NULL){
                if(item.year != 0){
                    authorsLabel.text = [NSString stringWithFormat:@"%@%@ (%i)",debugString,item.creatorSummary,item.year];
                }
                else{
                    authorsLabel.text = [NSString stringWithFormat:@"%@%@ (No date)",debugString,item.creatorSummary];
                }
            }    
            else if(item.year != 0){
                authorsLabel.text = [NSString stringWithFormat:@"%@No author (%i)",debugString,item.year];
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
    [[ZPDataLayer instance] registerItemObserver:self];
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
