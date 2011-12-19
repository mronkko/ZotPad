//
//  ZPNavigationItemListViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/4/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPNavigationItemListViewController.h"
#import "ZPItemListViewController.h"
#import "ZPZoteroItem.h"
#import "ZPDataLayer.h"


//TODO: Consider making a super class for this class and the ZPItemListView to avoid redundant code

@implementation ZPNavigationItemListViewController

static ZPNavigationItemListViewController* _instance = nil;

#pragma mark - Managing the detail item

-(id) init{
    self = [super init];
    _cellCache = [[NSCache alloc] init];
    _instance = self;                  
    return self;
}

+ (ZPNavigationItemListViewController*) instance{
    return _instance;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    return [_itemKeysShown count];
}

/*
 When an item is selected, we need to update what is shown in the item detail view
 */

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
        
}


- (void)notifyItemAvailable:(NSString*) key{
    
    
    NSEnumerator *e = [[self.tableView indexPathsForVisibleRows] objectEnumerator];
    
    NSIndexPath* indexPath;
    while ((indexPath = (NSIndexPath*) [e nextObject]) && indexPath.row <=[_itemKeysShown count]) {
        if([key isEqualToString:[_itemKeysShown objectAtIndex:indexPath.row]]){
            
            //Tell this cell to update because it just got data
            
            [self performSelectorOnMainThread:@selector(_refreshCellAtIndexPaths:) withObject:[NSArray arrayWithObject:indexPath] waitUntilDone:NO];
            
            break;
        }
    }
}

- (void) _refreshCellAtIndexPaths:(NSArray*)indexPaths{
    [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];
    
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    
    
    NSObject* keyObj = [_itemKeysShown objectAtIndex: indexPath.row];
    
    //It is possible that we do not yet have data for the full view. Sleep until we have it
    //More data is retrieved in the background
    
    // NSLog(@"Retrieving item for for %i",indexPath.row);
    
    
    NSString* key;
    if(keyObj==[NSNull null]){
        key=@"";
    }    
    else{
        key= (NSString*) keyObj;
        //NSLog(@"Got key %@",key);
    }    
    
	UITableViewCell* cell = [self->_cellCache objectForKey:key];
    
    if(cell==nil){
        
        
        ZPZoteroItem* item=NULL;
        if(![key isEqualToString:@""]) item = [[ZPDataLayer instance] getItemByKey:key];
        
        if(item==NULL){
            cell = [tableView dequeueReusableCellWithIdentifier:@"LoadingCell"];        
        }
        else{
            
            //NSLog(@"Not in cache, creating");
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
            
            
        }
        [_cellCache setObject:cell forKey:key];
    }
    
    return cell;
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
        
    [super viewDidLoad];
    //We do not want the user to use the navigator to go back.
    self.navigationItem.hidesBackButton = YES;

    _itemKeysShown = [[ZPItemListViewController instance] itemKeysShown];

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
