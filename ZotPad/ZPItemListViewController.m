//
//  ZPDetailViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPItemListViewController.h"
#import "ZPDataLayer.h"
#import "../DSActivityView/Sources/DSActivityView.h"
#import "ZPLocalization.h"
#import "ZPPreferences.h"
#import "ZPAttachmentThumbnailFactory.h"
#import "ZPAppDelegate.h"
#import "ZPLogger.h"

//TODO: Refactor so that these would not be needed
#import "ZPServerConnection.h"
#import "ZPDatabase.h"
#import "ZPCacheController.h"

#define SIZE_OF_TABLEVIEW_UPDATE_BATCH 25
#define SIZE_OF_DATABASE_UPDATE_BATCH 50

//A small helper class for performing configuration of uncanched items list in itemlistview

#pragma mark - Helper class for requesting item data from the server

@interface ZPUncachedItemsOperation : NSOperation {
@private
    NSString*_searchString;
    NSString*_collectionKey;
    NSNumber* _libraryID;
    NSString* _orderField;
    BOOL _sortDescending;
    ZPItemListViewController* _itemListController;
}

-(id) initWithItemListController:(ZPItemListViewController*)itemListController;

@end

@implementation ZPUncachedItemsOperation;

-(id) initWithItemListController:(ZPItemListViewController*)itemListController{
    self = [super init];
    _itemListController=itemListController;
    _searchString = itemListController.searchString;
    _collectionKey = itemListController.collectionKey;
    _libraryID = itemListController.libraryID;
    _orderField = itemListController.orderField;
    _sortDescending = itemListController.sortDescending;
    
    return self;
}

-(void)main {
    
    if ( self.isCancelled ) return;
    NSLog(@"Clearing table");
    
    [_itemListController clearTable];
    NSLog(@"Retrieving cached keys");
    NSArray* cacheKeys= [[ZPDataLayer instance] getItemKeysFromCacheForLibrary:_libraryID collection:_collectionKey
                                                                  searchString:_searchString orderField:_orderField sortDescending:_sortDescending];
    NSLog(@"Got cached keys");
    if ( self.isCancelled ) return;
    
    if([cacheKeys count]>0){
        NSLog(@"Configuring cached keys");
        
        [_itemListController configureCachedKeys:cacheKeys];
    }
    
    if(![[ZPPreferences instance] online]){
        [_itemListController configureUncachedKeys:[NSArray array]];
    }
    else{
        if ( self.isCancelled ) return;
        NSLog(@"Retrieving server keys");
        
        if([cacheKeys count]==0){
            NSLog(@"Making view busy");
            [_itemListController performSelectorOnMainThread:@selector(makeBusy) withObject:NULL waitUntilDone:FALSE];        
        }
        NSArray* serverKeys =[[ZPServerConnection instance] retrieveKeysInContainer:_libraryID collectionKey:_collectionKey searchString:_searchString orderField:_orderField sortDescending:_sortDescending];
        
        NSMutableArray* uncachedItems = [NSMutableArray arrayWithArray:serverKeys];
        [uncachedItems removeObjectsInArray:cacheKeys];
        
        //Check if the collection memberships are still valid in the cache
        if(_searchString == NULL || [_searchString isEqualToString:@""]){
            if([serverKeys count]!=[cacheKeys count] || [uncachedItems count] > 0){
                if(_collectionKey == NULL){
                    [[ZPDatabase instance] deleteItemKeysNotInArray:serverKeys fromLibrary:_libraryID];
                    NSLog(@"Deleted old items from library");
                    
                }
                else{
                    [[ZPDatabase instance] removeItemKeysNotInArray:serverKeys fromCollection:_collectionKey];
                    [[ZPDatabase instance] addItemKeys:uncachedItems toCollection:_collectionKey];
                    NSLog(@"Refreshed collection memberships in cache");
                    
                }
                
            }
        }
        
        if ( self.isCancelled ) return;
        
        //Add this into the queue if there are any uncached items
        if([uncachedItems count]>0){
            [[ZPCacheController instance] addToItemQueue:uncachedItems libraryID:_libraryID priority:YES];
            
            if(![_searchString isEqualToString:@""]){
                if(_collectionKey!=NULL && ! [_searchString isEqualToString:@""]) [[ZPCacheController instance] addToCollectionsQueue:(ZPZoteroCollection*)[ZPZoteroCollection dataObjectWithKey:_collectionKey]  priority:YES];
                else [[ZPCacheController instance] addToLibrariesQueue:(ZPZoteroLibrary*)[ZPZoteroLibrary dataObjectWithKey: _libraryID] priority:YES];
            }
        }
        
        if ( self.isCancelled ) return;
        NSLog(@"Setting server keys");
        
        [_itemListController configureUncachedKeys:uncachedItems];
    }
    
    
    
    
    
    
}
@end



//A helped class for setting sort buttons

#pragma mark - Helper class for configuring sort buttons

@interface ZPItemListViewController_sortHelper: UITableViewController{
    UIPopoverController* _popover;
    UIButton* _targetButton;
    NSArray* _fieldTitles;
    NSArray* _fieldValues;
}

@property (retain) UIPopoverController* popover;
@property (retain) UIButton* targetButton;

@end

@implementation ZPItemListViewController_sortHelper

@synthesize popover = _popover;
@synthesize targetButton = _targetButton;

-(id) init{
    self=[super init];
    
    NSMutableArray* fieldTitles = [NSMutableArray array];
    NSArray* fieldValues = [[ZPDataLayer instance] fieldsThatCanBeUsedForSorting];
    
    for(NSString* value in fieldValues){
        [fieldTitles addObject:[ZPLocalization getLocalizationStringWithKey:value type:@"field"]];
    }
    
    _fieldTitles = [fieldTitles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    NSMutableArray* sortedFieldValues = [NSMutableArray array];
    
    for(NSString* title in _fieldTitles){
        [sortedFieldValues addObject:[fieldValues objectAtIndex:[fieldTitles indexOfObjectIdenticalTo:title]]];
    }
    
    _fieldValues = sortedFieldValues;
    
    
    self.tableView = [[UITableView alloc] init];
    self.tableView.delegate =self;
    self.tableView.dataSource =self;
    
    _popover = [[UIPopoverController alloc] initWithContentViewController:self];

    return self;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell* cell = [[UITableViewCell alloc] init];
    cell.textLabel.text = [_fieldTitles objectAtIndex:indexPath.row];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [_fieldValues count];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    NSString* orderField = [_fieldValues objectAtIndex:indexPath.row];
    //Because this preference is not used anywhere else, it is accessed directly.
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:orderField forKey:[NSString stringWithFormat: @"itemListView_sortButton%i",_targetButton.tag]];

    UILabel* label = (UILabel*)[_targetButton.subviews objectAtIndex:1];
    
    [label setText:[ZPLocalization getLocalizationStringWithKey:orderField type:@"field"]];
    
    [_popover dismissPopoverAnimated:YES];
}

@end


#pragma mark - Start of main class

@interface ZPItemListViewController (){
    NSOperationQueue* _uiEventQueue;
    ZPItemListViewController_sortHelper* _sortHelper;
}

@property (strong, nonatomic) UIPopoverController *masterPopoverController;

-(void) _updateRowForItem:(ZPZoteroItem*)item;
-(void) _performRowInsertions:(NSArray*)insertIndexPaths reloads:(NSArray*)reloadIndexPaths tableLength:(NSNumber*)tableLength;
-(void) _performTableUpdates:(BOOL)animated;
-(void) _refreshCellAtIndexPaths:(NSArray*)indexPath;
-(void) _configureSortButton:(UIButton*)button;

@end

@implementation ZPItemListViewController

@synthesize collectionKey = _collectionKey;
@synthesize libraryID =  _libraryID;
@synthesize searchString = _searchString;
@synthesize orderField = _orderField;
@synthesize sortDescending = _sortDescending;

@synthesize masterPopoverController = _masterPopoverController;

@synthesize tableView = _tableView;
@synthesize searchBar = _searchBar;
@synthesize toolBar = _toolBar;

@synthesize itemKeysShown = _itemKeysShown;
@synthesize itemDetailViewController =  _itemDetailViewController;


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - Methods for configuring the view

- (void)configureView
{
    //Clear item keys shown so that UI knows to stop drawing the old items

    if(_libraryID!=0){

        [[ZPDataLayer instance] removeItemObserver:self];
        
        if([NSThread isMainThread]){
            
            
            if (self.masterPopoverController != nil) {
                [self.masterPopoverController dismissPopoverAnimated:YES];
            }
            
            
            [self makeAvailable];
            
            // Retrieve the item IDs if a library is selected. 
            
            
            if([[ZPPreferences instance] online]) [_activityIndicator startAnimating];
            
            
            //This queue is only used for retrieving key lists for uncahced items, so we can just invalidate all previous requests
            [_uiEventQueue cancelAllOperations];
            ZPUncachedItemsOperation* operation = [[ZPUncachedItemsOperation alloc] initWithItemListController:self];
            [_uiEventQueue addOperation:operation];
            NSLog(@"UI update events in queue %i",[_uiEventQueue operationCount]);
            
        }
        else{
            [self performSelectorOnMainThread:@selector(configureView) withObject:NULL waitUntilDone:FALSE];
        }

    }
}

/*
 Called from data layer to notify that there is data for this view and it can be shown
 */

- (void)clearTable{
    
    _invalidated = TRUE;
    
    @synchronized(_tableView){
        
        BOOL needsReload = [self tableView:_tableView numberOfRowsInSection:0]>1;
        
        _itemKeysNotInCache = [NSMutableArray array];
        _itemKeysShown = [NSArray array];
        
        //We do not need to observe for new item events if we do not have a list of unknown keys available
        [[ZPDataLayer instance] removeItemObserver:self];
        
        //TODO: Investigate why a relaodsection call a bit below causes a crash. Then uncomment these both.
        //[_tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
        if(needsReload){
            [_tableView performSelectorOnMainThread:@selector(reloadData) withObject:NULL waitUntilDone:YES];
            NSLog(@"Reloaded data (1). Number of rows now %i",[self tableView:_tableView  numberOfRowsInSection:0]);
        }
    }
}

- (void) configureCachedKeys:(NSArray*)array{
    
    @synchronized(_tableView){
        
        _itemKeysShown = array;
        [_tableView performSelectorOnMainThread:@selector(reloadData) withObject:NULL waitUntilDone:YES];
        NSLog(@"Reloaded data (2). Number of rows now %i",[self tableView:_tableView  numberOfRowsInSection:0]);
        
    }
}


- (void) configureUncachedKeys:(NSArray*)uncachedItems{
    
    //Only update the uncached keys if we are still showing the same item key list
    _itemKeysNotInCache = [NSMutableArray arrayWithArray:uncachedItems];
    _invalidated = FALSE;
    [[ZPDataLayer instance] registerItemObserver:self];
    [self _performTableUpdates:FALSE];
    [self performSelectorOnMainThread:@selector(makeAvailable) withObject:NULL waitUntilDone:NO];
    NSLog(@"Configured uncached keys");
    
    
}

//If we are not already displaying an activity view, do so now

- (void)makeBusy{
    if(_activityView==NULL){
        if([NSThread isMainThread]){
            [self.tableView setUserInteractionEnabled:FALSE];
            _activityView = [DSBezelActivityView newActivityViewForView:self.tableView];
        }
        else{
            [self performSelectorOnMainThread:@selector(makeBusy) withObject:nil waitUntilDone:NO];
        }   
    }
}


- (void)makeAvailable{
    if(_activityView!=NULL){
        if([NSThread isMainThread]){
            [DSBezelActivityView removeViewAnimated:YES];
            _activityView = NULL;
            [self.tableView setUserInteractionEnabled:TRUE];
        }
        else{
            [self performSelectorOnMainThread:@selector(makeAvailable) withObject:nil waitUntilDone:NO];
        }   
    }

}
        
        
#pragma mark - Receiving data and updating the table view

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
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[_itemKeysShown indexOfObject:item.key] inSection:0];
    //Do not reload cell if it is selected
    if(! [[_tableView indexPathForSelectedRow] isEqual:indexPath]) [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:_animations];
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
}- (void) _refreshCellAtIndexPaths:(NSArray*)indexPaths{
    [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];

}

#pragma mark - Table view data source and delegate methods


- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section. Initially there is no library selected, so we will just return an empty view
    NSInteger count=1;
    if(_itemKeysShown!=nil){
        count= MAX(1,[_itemKeysShown count]);
    }
    NSLog(@"Item table has now %i rows",count);
    return count;
}


- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSLog(@"Getting cell for row %i",indexPath.row);

   
    //If the data has become invalid, return a cell 

    if(indexPath.row>=[_itemKeysShown count]){
        NSString* identifier;
        if(_libraryID==0){
            identifier = @"ChooseLibraryCell";   
        }
        else if(_invalidated){
            identifier = @"BlankCell";
        }
        else{
            identifier=@"NoItemsCell";
        }
        NSLog(@"Cell identifier is %@",identifier);
        
        return [aTableView dequeueReusableCellWithIdentifier:identifier];
    }
    NSObject* keyObj = [_itemKeysShown objectAtIndex: indexPath.row];


    
    NSString* key;
    if(keyObj==[NSNull null] || keyObj==NULL){
        key=@"";
    }    
    else{
        key= (NSString*) keyObj;
    }    
    
	UITableViewCell* cell;
    
        
        //TODO: Set author and year to empty if not defined. 
        ZPZoteroItem* item=NULL;
        if(![key isEqualToString:@""]) item = (ZPZoteroItem*) [ZPZoteroItem dataObjectWithKey:key];
        
        if(item==NULL){
            cell = [aTableView dequeueReusableCellWithIdentifier:@"LoadingCell"]; 
            NSLog(@"Cell identifier is LoadingCell");
        }
        else{

            cell = [aTableView dequeueReusableCellWithIdentifier:@"ZoteroItemCell"];
            NSLog(@"Cell identifier is ZoteroItemCell");
            
            UILabel *titleLabel = (UILabel *)[cell viewWithTag:1];
            titleLabel.text = item.title;
            
            UILabel *authorsLabel = (UILabel *)[cell viewWithTag:2];
            
            //Show different things depending on what data we have
            if(item.creatorSummary!=NULL){
                if(item.year!= 0){
                    authorsLabel.text = [NSString stringWithFormat:@"%@ (%i)",item.creatorSummary,item.year];
                }
                else{
                    authorsLabel.text = [NSString stringWithFormat:@"%@ (No date)",item.creatorSummary];
                }
            }    
            else if(item.year!= 0){
                authorsLabel.text = [NSString stringWithFormat:@"No author (%i)",item.year];
            }

            //Publication as a formatted label

            NSString* publishedIn = item.publicationDetails;
            
            if(publishedIn == NULL){
                publishedIn=@"";   
            }
            
            //Does this cell already have a TTStyledTextLabel
            NSEnumerator* e = [[cell subviews] objectEnumerator];

            TTStyledTextLabel* publishedInLabel;

            NSObject* subView;
            while(subView = [e nextObject]){
                if([subView isKindOfClass:[TTStyledTextLabel class]]){
                    publishedInLabel = (TTStyledTextLabel*) subView;
                    break;
                }
            }
                  
            if(publishedInLabel == NULL){
                CGRect frame = CGRectMake(CGRectGetMinX(authorsLabel.frame),CGRectGetMaxY(authorsLabel.frame),CGRectGetWidth(cell.frame)-CGRectGetMinX(authorsLabel.frame),CGRectGetHeight(cell.frame)-CGRectGetMaxY(authorsLabel.frame)-2);
                publishedInLabel = [[TTStyledTextLabel alloc] 
                                            initWithFrame:frame];
                [publishedInLabel setFont:[UIFont systemFontOfSize:12]];
                [publishedInLabel setClipsToBounds:TRUE];
                [cell addSubview:publishedInLabel];
            }
            TTStyledText* text = [TTStyledText textFromXHTML:[publishedIn stringByReplacingOccurrencesOfString:@" & " 
                                                                                                    withString:@" &amp; "] lineBreaks:YES URLs:NO];
            [publishedInLabel setText:text];
            
            //Attachment icon
            
            UIButton* articleThumbnail = (UIButton *) [cell viewWithTag:4];
            
            //Check if the item has attachments and render a thumbnail from the first attachment PDF
            
            if(articleThumbnail!= NULL && [item.attachments count] > 0){
                [articleThumbnail setHidden:FALSE];
                
                 ZPZoteroAttachment* attachment = [item.attachments objectAtIndex:0];
                
                UIImage* image = [[ZPAttachmentThumbnailFactory instance] getFiletypeImage:attachment height:articleThumbnail.frame.size.height width:articleThumbnail.frame.size.width];
                [articleThumbnail setImage:image forState:UIControlStateNormal];
                [articleThumbnail setEnabled:(attachment.fileExists || [[ZPPreferences instance] online])];
            }
            else{
                [articleThumbnail setHidden:TRUE];
            }
            
    }
    return cell;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    // Make sure your segue name in storyboard is the same as this line
    if ([[segue identifier] isEqualToString:@"PushItemDetailView"])
    {
        ZPItemDetailViewController* target = (ZPItemDetailViewController*)[segue destinationViewController];
        
        // Get the selected row from the item list
        NSIndexPath* indexPath = [_tableView indexPathForSelectedRow];
        
        // Get the key for the selected item 
        NSString* currentItemKey = [_itemKeysShown objectAtIndex: indexPath.row]; 
        [target setSelectedItem:(ZPZoteroItem*)[ZPZoteroItem dataObjectWithKey:currentItemKey]];
        
        // Set the navigation controller
        UITableViewController * simpleItemListViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"NavigationItemListView"];
        simpleItemListViewController.navigationItem.hidesBackButton = YES;
        
        [simpleItemListViewController.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionMiddle]; 
        [simpleItemListViewController.tableView setDelegate: self];
        [simpleItemListViewController.tableView setDataSource: self];
        
        ZPAppDelegate* appDelegate = (ZPAppDelegate*)[[UIApplication sharedApplication] delegate];
                                      
        [[[(UISplitViewController*)appDelegate.window.rootViewController viewControllers] lastObject] pushViewController:simpleItemListViewController animated:YES];

        
    }
    
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{

    [super viewDidLoad];
    
	
    
    // Do any additional setup after loading the view, typically from a nib.
    
    //Configure objects
    

    _animations = UITableViewRowAnimationNone;
    _uiEventQueue =[[NSOperationQueue alloc] init];
    [_uiEventQueue setMaxConcurrentOperationCount:3];

    
    
    //Set up activity indicator. 

    _activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0,0,20, 20)];
    [_activityIndicator hidesWhenStopped];
    UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:_activityIndicator];
    self.navigationItem.rightBarButtonItem = barButton;
    

    //Configure the sort buttons based on preferences
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    UIBarButtonItem* spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];  
    NSMutableArray* toobarItems=[NSMutableArray arrayWithObject:spacer];

    NSInteger buttonCount;

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) buttonCount = 6;
    else buttonCount = 4;
    
    for(NSInteger i = 1; i<=buttonCount; ++i){
        //Because this preference is not used anywhere else, it is accessed directly.
        NSString* orderField =  [defaults objectForKey:[NSString stringWithFormat: @"itemListView_sortButton%i",i]];
        NSString* title;
        if(orderField != NULL){
            title = [ZPLocalization getLocalizationStringWithKey:orderField type:@"field"];
        }
        else if(i<5){
            if(i==1) orderField =  @"title";
            else if(i==2) orderField =  @"creator";
            else if(i==3) orderField =  @"date";
            else if(i==4) orderField =  @"dateModified";
            
            [defaults setObject:orderField forKey:[NSString stringWithFormat: @"itemListView_sortButton%i",i]];
            title = [ZPLocalization getLocalizationStringWithKey:orderField type:@"field"];

        }
        else{
            title = @"Tap and hold to set";
        }
        
        UIButton* button  = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(0,0, 101, 30);
        [button setImage:[UIImage imageNamed:@"barbutton_image_up_state.png"] forState:UIControlStateNormal];
        [button setImage:[UIImage imageNamed:@"barbutton_image_down_state.png"] forState:UIControlStateHighlighted];
        
        UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(0,0, 90, 30)];
        
        label.textAlignment = UITextAlignmentCenter;
        label.adjustsFontSizeToFitWidth = YES;
        label.text = title;
        label.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor whiteColor];
        label.center = button.center;
        label.font =  [UIFont fontWithName:@"Helvetica" size:12.0f];
        
        [button addSubview:label];
        
        [button addTarget:self action:@selector(sortButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        button.tag = i;
        
        UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(sortButtonLongPressed:)];
        [button addGestureRecognizer:longPressRecognizer]; 

        UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:button];
        barButton.tag=i;

        [toobarItems addObject:barButton];
        [toobarItems addObject:spacer];


    }
    [_toolBar setItems:toobarItems];
    
    
    [self configureView];
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

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Libraries", @"Libraries");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

#pragma mark - Actions

-(IBAction) sortButtonPressed:(id)sender{

    
    if(_sortHelper!=NULL && [_sortHelper.popover isPopoverVisible]) [_sortHelper.popover dismissPopoverAnimated:YES];

    _tagForActiveSortButton = [(UIView*)sender tag];
    
    //Because this preference is not used anywhere else, it is accessed directly.
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* orderField =  [defaults objectForKey:[NSString stringWithFormat: @"itemListView_sortButton%i",[sender tag]]];
    if(orderField == NULL){
        [self _configureSortButton:sender];
    }
        
    else{
        if([orderField isEqualToString: _orderField ]){
        _sortDescending = !_sortDescending;
        }
        else{
            _orderField = orderField;
            _sortDescending = FALSE;
        }
        
        [self configureView];
    }

}


-(void) sortButtonLongPressed:(UILongPressGestureRecognizer*)sender{
    
    if(sender.state == UIGestureRecognizerStateBegan ){
        [self _configureSortButton:(UIButton*)[sender view]];
    }
}


-(void) _configureSortButton:(UIButton*)sender{
    
    _tagForActiveSortButton = sender.tag;
    
    UIBarButtonItem* button;
    for(button in _toolBar.items){
        if(button.tag == _tagForActiveSortButton) break;
    }
    
    if(_sortHelper == NULL){
        _sortHelper = [[ZPItemListViewController_sortHelper alloc] init];        
    }
    
    if([_sortHelper.popover isPopoverVisible]) [_sortHelper.popover dismissPopoverAnimated:YES];
        
    _sortHelper.targetButton = (UIButton*) button.customView;
    [_sortHelper.popover presentPopoverFromBarButtonItem:button permittedArrowDirections: UIPopoverArrowDirectionAny animated:YES];
}

-(IBAction) attachmentThumbnailPressed:(id)sender{

    //Get the table cell.
    UITableViewCell* cell = (UITableViewCell* )[[sender superview] superview];
    
    //Get the row of this cell
    NSInteger row = [_tableView indexPathForCell:cell].row;
    
    ZPZoteroItem* item = (ZPZoteroItem*) [ZPZoteroItem dataObjectWithKey:[_itemKeysShown objectAtIndex:row]];
    
    [[ZPQuicklookController instance] openItemInQuickLook:item attachmentIndex:0 sourceView:self];

}


-(void) clearSearch{
    _searchString = NULL;
    [_searchBar setText:@""];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sourceSearchBar{
    
    if(![[sourceSearchBar text] isEqualToString:_searchString]){
        _searchString = [sourceSearchBar text];
        [self configureView];
    }
    [sourceSearchBar resignFirstResponder ];
}

@end
