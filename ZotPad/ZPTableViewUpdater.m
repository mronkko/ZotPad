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
            NSArray* oldContentArray = [(ZPItemListDataSource*) tableView.dataSource contentArray];
            
            NSMutableArray* currentContentArray = [NSMutableArray arrayWithArray:oldContentArray];
            
            if(animated){
                NSInteger index=0;
                reloadIndices = [NSMutableArray array];
                insertIndices = [NSMutableArray array];
                deleteIndexPaths = [NSMutableArray array];
                
                for(NSObject* contentKey in newContentArray){
                    
                    //If we hit placeholders, stop processing.
                    if(contentKey == [NSNull null]) break;
                    
                    //If this is the first cell and there is currently a placeholder, reload
                    if(index == 0 && [currentContentArray count] == 0 && [tableView numberOfRowsInSection:0] == 1){
                        [reloadIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                        [currentContentArray replaceObjectAtIndex:index withObject:contentKey];
                    }
                    //If the old content is shorter than the new content, add cells
                    else if([currentContentArray count]<=index){
                        [insertIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                        [currentContentArray insertObject:contentKey atIndex:index];
                    }
                    //If there is currently a NULL cell, reload it
                    else if([currentContentArray objectAtIndex:index] == [NSNull null]){
                        [reloadIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                        [currentContentArray replaceObjectAtIndex:index withObject:contentKey];
                    }
                    
                    // There is content in the way and the content is not the same as the new content
                    // and we will insert before that content
                    
                    else if(![contentKey isEqual:[currentContentArray objectAtIndex:index]]){
                        [insertIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                        [currentContentArray insertObject:contentKey atIndex:index];
                    }
                    index++;
                }
                
                //Add empty rows to the end if needed
                
                while([currentContentArray count] < [newContentArray count]){
                    [insertIndices addObject:[NSIndexPath indexPathForRow:[insertIndices count] + [currentContentArray count] inSection:0]];
                    [currentContentArray addObject:[NSNull null]];
                }
                
                // Trim extra rows from the end if needed
                
                NSInteger deleteIndex =[newContentArray count];
                
                while([currentContentArray count] > deleteIndex){
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
                    
                    if(oldContentArray == [(ZPItemListDataSource*) tableView.dataSource contentArray]){
                        
                        if(animated){
                            
                            
                            /*
                             NSLog(@"INSERT %@",insertIndices);
                             NSLog(@"RELOAD %@",reloadIndices);
                             NSLog(@"DELETE %@",deleteIndexPaths);
                             
                             NSLog(@"Current rows %i",[tableView numberOfRowsInSection:0]);
                             NSLog(@"Inserts %i",[insertIndices count]);
                             NSLog(@"Reloads %i",[reloadIndices count]);
                             NSLog(@"Deletes %i",[deleteIndexPaths count]);
                             NSLog(@"New content %i",[newContentArray count]);
                             */
                            [(ZPItemListDataSource*) tableView.dataSource setContentArray:currentContentArray];
                            
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
                        else{
                            //Set the new content
                            [(ZPItemListDataSource*) tableView.dataSource setContentArray:newContentArray];
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
