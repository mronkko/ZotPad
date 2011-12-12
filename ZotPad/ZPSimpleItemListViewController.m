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


//TODO: Consider making a super class for this class and the ZPItemListView to avoid redundant code

@implementation ZPSimpleItemListViewController

@synthesize itemKeysShown = _itemKeysShown;
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

- (void) _refreshCellAtIndexPaths:(NSArray*)indexPaths{
    [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];
    
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
