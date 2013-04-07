//
//  ZPTableViewUpdater.m
//  ZotPad
//
//  Contains the logic for updating table view content
//
//  Created by Mikko Rönkkö on 1/15/13.
//
//

#import "ZPTableViewUpdater.h"
#import "ZPItemListDataSource.h"
#import "ZPCore.h"
#import "ZPItemList.h"

@implementation ZPTableViewUpdater

+(void) updateTableView:(UITableView*) tableView withContentArray:(NSArray*)newContentArray withAnimations:(BOOL)animated{
    //This can be performance intensive, so execute it in background
    if([NSThread isMainThread] && animated){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [self updateTableView:tableView withContentArray:newContentArray withAnimations:animated];
        });
    }
    else{
        //Only one thread at a time can make changes in the table
        @synchronized(tableView){
            
            // If we are loading the new keys with animations, we need to determine which rows to insert, reload, and delete
            
            NSMutableArray* reloadIndices;
            NSMutableArray* insertIndices;
            NSMutableArray* deleteIndexPaths;
            
            // Take a pointer to the old content array to check if the content has been changed
            NSArray* contentArrayBeforeTableUpdates = [(ZPItemListDataSource*) tableView.dataSource contentArray];
            
            NSMutableArray* contentArrayAfterInsertsAndUpdates = [NSMutableArray arrayWithArray:contentArrayBeforeTableUpdates];
            
            if(animated){
                NSInteger index=0;
                reloadIndices = [NSMutableArray array];
                insertIndices = [NSMutableArray array];
                deleteIndexPaths = [NSMutableArray array];
                
                for(NSObject* contentKey in newContentArray){
                    
                    //If we hit placeholders, stop processing.
                    if(contentKey == [NSNull null]) break;
                    
                    //If this is the first cell and there is currently a placeholder, reload
                    if(index == 0 && [contentArrayAfterInsertsAndUpdates count] == 0 && [tableView numberOfRowsInSection:0] == 1){
                        [reloadIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                        [contentArrayAfterInsertsAndUpdates replaceObjectAtIndex:index withObject:contentKey];
                    }
                    //If the old content is shorter than the new content, add cells
                    else if([contentArrayAfterInsertsAndUpdates count]<=index){
                        [insertIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                        [contentArrayAfterInsertsAndUpdates insertObject:contentKey atIndex:index];
                    }
                    //If there is currently a NULL cell, reload it
                    else if([contentArrayAfterInsertsAndUpdates objectAtIndex:index] == [NSNull null]){
                        [reloadIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                        [contentArrayAfterInsertsAndUpdates replaceObjectAtIndex:index withObject:contentKey];
                    }
                    
                    // There is content in the way and the content is not the same as the new content
                    // and we will insert before that content
                    
                    else if(![contentKey isEqual:[contentArrayAfterInsertsAndUpdates objectAtIndex:index]]){
                        [insertIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                        [contentArrayAfterInsertsAndUpdates insertObject:contentKey atIndex:index];
                    }
                    index++;
                }
                
                //Add empty rows to the end if needed
                
                while([contentArrayAfterInsertsAndUpdates count] < [newContentArray count]){
                    [insertIndices addObject:[NSIndexPath indexPathForRow:[insertIndices count] + [contentArrayAfterInsertsAndUpdates count] inSection:0]];
                    [contentArrayAfterInsertsAndUpdates addObject:[NSNull null]];
                }
                
                // Trim extra rows from the end if needed
                
                NSInteger deleteIndex =[newContentArray count];
                
                while([contentArrayAfterInsertsAndUpdates count] > deleteIndex){
                    [deleteIndexPaths addObject:[NSIndexPath indexPathForRow:deleteIndex++ inSection:0]];
                }
            }
            
            
            /*
             This is the only place where we are allowed to edit the table and it must be done in the main thread
             */
            
            void (^tableUpdateBlock)() = ^{
                
                @synchronized(tableView){
                    
                    // It is possible that there has been an update to the tableview before this block has a
                    // change to execute. Ensure that the table content has not changed before doing updates
                    
                    if(contentArrayBeforeTableUpdates == [(ZPItemListDataSource*) tableView.dataSource contentArray]){
                        
                        if(animated){
                            
                            
                            // Do final consistency checks.
                            NSInteger maxRowIndex=-1;
                            for(NSIndexPath* insertIndex in insertIndices){
                                maxRowIndex = MAX(maxRowIndex, insertIndex.row);
                            }
                                                        
                            if([insertIndices count] + [contentArrayBeforeTableUpdates count] != [contentArrayAfterInsertsAndUpdates count]){
                                DDLogError(@"Consistency check failed when attempting to update the item list. Length of new content (%i) is not the sum of length of old content (%i) plus the number of inserted rows (%i)",
                                           [contentArrayAfterInsertsAndUpdates count],
                                           [contentArrayBeforeTableUpdates count],
                                           [insertIndices count]);
                            }
                            else if((NSInteger)[contentArrayAfterInsertsAndUpdates count] <= maxRowIndex){
                                DDLogError(@"Consistency check failed when attempting to update the item list. Attempted to insert a row (%i) after the end of the table (length %i).",
                                           maxRowIndex,
                                           [contentArrayAfterInsertsAndUpdates count]);
                            }
                            else{
                                
                                [(ZPItemListDataSource*) tableView.dataSource setContentArray:contentArrayAfterInsertsAndUpdates];
                                
                                if([insertIndices count]>0){
                                    [tableView insertRowsAtIndexPaths:insertIndices withRowAnimation:UITableViewRowAnimationAutomatic];
                                }
                                if([reloadIndices count]>0){
                                    [tableView reloadRowsAtIndexPaths:reloadIndices withRowAnimation:UITableViewRowAnimationAutomatic];
                                }
                                if(deleteIndexPaths.count > 0){
                                    [(ZPItemListDataSource*) tableView.dataSource setContentArray:newContentArray];
                                    [tableView deleteRowsAtIndexPaths:deleteIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
                                }
                            }
                            
                            
                            
                        }
                        else{
                            //Set the new content
                            [(ZPItemListDataSource*) tableView.dataSource setContentArray:newContentArray];
                            
                            //TODO: Refactor so that the following line is not needed
                            [[ZPItemList instance] setItemKeysShown:newContentArray];
                            
                            [tableView reloadData];
                        }
                    }
                }
            };
            
            if([NSThread isMainThread]){
                tableUpdateBlock();
            }
            else{
                dispatch_async(dispatch_get_main_queue(), tableUpdateBlock);
            }
        }
    }
}

@end
