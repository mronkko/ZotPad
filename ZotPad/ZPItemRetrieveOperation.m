//
//  ZPItemRetrieveOperation.m
//  ZotPad
//
//  Check the header file for documentation
//
//  See: Tutorial on NSOperation http://developer.apple.com/cocoa/managingconcurrency.html
//
//  Created by Rönkkö Mikko on 11/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPItemRetrieveOperation.h"
#import "ZPDataLayer.h"
#import "ZPZoteroItem.h"
#import "ZPServerConnection.h"
#import "ZPServerResponseXMLParser.h"

@implementation ZPItemRetrieveOperation


-(id) initWithArray:(NSMutableArray*)itemArray library:(NSInteger)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString OrderField:(NSString*)OrderField sortDescending:(BOOL)sortIsDescending queue:(NSOperationQueue*) queue{
    self = [super init];

    _itemIDs=itemArray;
    _libraryID=libraryID;
    _collectionKey=collectionKey;
    _searchString=searchString;
    _OrderField=OrderField;
    _sortIsDescending=sortIsDescending;
    
    
    return self;
}

/*
 
 Calling this method tells the item retrieve operation that it is no longer workign for the active view
 
 */


-(void) markAsNotWithActiveView{
    if(_initial){
        _notWithActiveView = YES;
    }
    else{
        [self cancel];
    }
}

/*
 
 Marks this operation as initial cache request.
 
*/
-(void) markAsInitialRequestForCollection{
    [self setQueuePriority:NSOperationQueuePriorityLow];
    _initial=YES;
}
// Calls the methods for retrieving data

-(void)main {
    
    int offset;
    //Find offset by going through the item ID array
    for (offset = 0; offset < [_itemIDs count] && [_itemIDs objectAtIndex:offset] != [NSNull null]; offset++); 
    
    while( ! self.isCancelled) {
    
        ZPServerResponseXMLParser* parserResults = [[ZPServerConnection instance] retrieveItemsFromLibrary:_libraryID collection:_collectionKey searchString:_searchString orderField:_OrderField sortDescending:_sortIsDescending limit:50 start:offset];
        
        if(parserResults==NULL) return;
    
        //Fill in what we got from the parser 
    
        for (int i = 0; i < [[parserResults parsedElements] count]; i++) {
            ZPZoteroItem* item = (ZPZoteroItem*)[[parserResults parsedElements] objectAtIndex:i];
            [_itemIDs replaceObjectAtIndex:(i+offset) withObject: [item key]];
        }
    
        //Que an operation to cache these items
    
        [[ZPDataLayer instance] cacheZoteroItems:[parserResults parsedElements]];
              
        offset=offset+50;

        //Check if we still have items to retrieve

        if(offset>[_itemIDs count]){
            if(_initial){
                //TODO: Mark that this collection is now fully cached.
                //TODO: At the same time refresh collection memberships in the cache http://stackoverflow.com/questions/1609637/is-it-possible-to-insert-multiple-rows-at-a-time-in-an-sqlite-database
            }
            return;
        }
       
        // If we have a collection that is more than halfway done, but that is no longer the active collection, 
        // start workign on that with a very low priority operation and cancel this operation.
        // the operation queue will not be passed further to this new operation because it is no longer needed
        
        else if(_initial && _queue!=NULL && ! [_collectionKey isEqualToString: [[ZPDataLayer instance] currentlyActiveCollectionKey]]) {
            if(offset > [_itemIDs count]/2){
                ZPItemRetrieveOperation* operation = [[ZPItemRetrieveOperation alloc] initWithArray:_itemIDs library:_libraryID collection:_collectionKey searchString:_searchString OrderField:_OrderField sortDescending:_sortIsDescending queue:NULL];
                [operation setQueuePriority:NSOperationQueuePriorityVeryLow];
                [_queue addOperation:operation];
            }
            
            [self cancel];
        }
        
    }
}

@end
