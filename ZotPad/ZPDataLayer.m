
//
//  ZPDataLayer.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPDataLayer.h"

//Data objects
#import "ZPZoteroLibrary.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroAttachment.h"
#import "ZPZoteroNote.h"

//Cache
#import "ZPCacheController.h"

//Server connection
#import "ZPServerConnection.h"
#import "ZPServerResponseXMLParser.h"

//DB and DB library
#import "ZPDatabase.h"
#import "ZPLogger.h"


//A small helper class for performing configuration of uncanched items list in itemlistview

@interface ZPUncachedItemsOperation : NSOperation {
@private
    NSString*_searchString;
    NSString*_collectionKey;
    NSNumber* _libraryID;
    NSString* _orderField;
    BOOL _sortDescending;
    ZPDetailedItemListViewController* _itemListController;
}

-(id) initWithItemListController:(ZPDetailedItemListViewController*)itemListController;

@end

@implementation ZPUncachedItemsOperation;

-(id) initWithItemListController:(ZPDetailedItemListViewController*)itemListController{
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

    [[ZPCacheController instance] setActiveLibrary:_libraryID collection:_collectionKey];
    
    NSArray* serverKeys =[[ZPServerConnection instance] retrieveKeysInContainer:_libraryID collectionKey:_collectionKey searchString:_searchString orderField:_orderField sortDescending:_sortDescending];

    if ( self.isCancelled ) return;
    
    //Remove items that we have in the cache
       
    NSArray* cachedKeys = [[ZPDatabase instance] getItemKeysForLibrary:_libraryID collectionKey:_collectionKey searchString:_searchString orderField:_orderField sortDescending:_sortDescending];

    if ( self.isCancelled ) return;

    
    NSMutableArray* uncachedItems = [NSMutableArray arrayWithArray:serverKeys];
    [uncachedItems removeObjectsInArray:cachedKeys];
    
    //Check if the collection memberships are still valid in the cache
    if(_searchString == NULL || [_searchString isEqualToString:@""]){
        if([serverKeys count]!=[cachedKeys count] || [uncachedItems count] > 0){
            if(_collectionKey == NULL){
                [[ZPDatabase instance] deleteItemKeysNotInArray:serverKeys fromLibrary:_libraryID];
            }
            else{
                [[ZPDatabase instance] removeItemKeysNotInArray:serverKeys fromCollection:_collectionKey];
                [[ZPDatabase instance] addItemKeys:uncachedItems toCollection:_collectionKey];
            }
            
        }
    }

    if ( self.isCancelled ) return;

    //Add this into the queue if there are any uncached items
    if([uncachedItems count]>0){
        [[ZPCacheController instance] addToItemQueue:uncachedItems libraryID:_libraryID priority:YES];
        
        if(![_searchString isEqualToString:@""]){
            if(_collectionKey!=NULL && ! [_searchString isEqualToString:@""]) [[ZPCacheController instance] addToCollectionsQueue:[ZPZoteroCollection ZPZoteroCollectionWithKey:_collectionKey]  priority:YES];
            else [[ZPCacheController instance] addToLibrariesQueue:[ZPZoteroLibrary ZPZoteroLibraryWithID: _libraryID] priority:YES];
        }
    }
    
    if ( self.isCancelled ) return;
    
    [_itemListController configureUncachedKeys:uncachedItems];
}
@end

//Private methods 

@interface ZPDataLayer ();



@end


@implementation ZPDataLayer


static ZPDataLayer* _instance = nil;


-(id)init
{
    self = [super init];
    
    _itemObservers = [[NSMutableSet alloc] initWithCapacity:2];
    _libraryObservers = [[NSMutableSet alloc] initWithCapacity:3];
    _attachmentObservers = [[NSMutableSet alloc] initWithCapacity:2];
    
    _serverRequestQueue = [[NSOperationQueue alloc] init];
    
    _serverRequestQueue.maxConcurrentOperationCount = 2;
    
	return self;
}

/*
    Singleton accessor
 */

+(ZPDataLayer*) instance {
    if(_instance == NULL){
        _instance = [[ZPDataLayer alloc] init];
    }
    return _instance;
}


/*
 
 Returns an array containing all libraries  
 
 */

- (NSArray*) libraries {
	
    return [[ZPDatabase instance] libraries];
}


/*
 
 Returns an array containing all libraries with their collections 
 
 */

- (NSArray*) collectionsForLibrary : (NSNumber*)currentLibraryID withParentCollection:(NSString*)currentcollectionKey {
	
    return [[ZPDatabase instance] collectionsForLibrary:currentLibraryID withParentCollection:currentcollectionKey];

}


/*
 
 Creates an array that will hold the item IDs of the current view. Initially contains only 15 first
    IDs with the rest of the item ids set to 0 and populated later in the bacground.

 */


- (NSArray*) getItemKeysFromCacheForLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending{
    return [[ZPDatabase instance] getItemKeysForLibrary:libraryID collectionKey:collectionKey searchString:searchString orderField:orderField sortDescending:sortDescending];
}



-(void) updateItemDetailsFromServer:(ZPZoteroItem*)item{
    
    [[ZPCacheController instance] refreshActiveItem:item];
}



- (void) uncachedItemKeysForView:(ZPDetailedItemListViewController*)listViewController{
    
    //This queue is only used for retrieving key lists for uncahced items, so we can just invalidate all previous requests
    [_serverRequestQueue cancelAllOperations];
    ZPUncachedItemsOperation* operation = [[ZPUncachedItemsOperation alloc] initWithItemListController:listViewController];
    [_serverRequestQueue addOperation:operation];
}


-(void) notifyItemsAvailable:(NSArray*)items{
    ZPZoteroItem* item;
    NSMutableArray* itemsToBeNotifiedAbout = [NSMutableArray array];

    //Check subitems 
    for(item in items){
        //If this is a subitem, notify about the parent if it is not already included
        if([item respondsToSelector:@selector(parentItemKey)]){
            NSString* parentKey = (NSString*)[item performSelector:@selector(parentItemKey)];
            if(![parentKey isEqualToString:item.key]){
                ZPZoteroItem* parentItem = [ZPZoteroItem retrieveOrInitializeWithKey:parentKey];
                
                //For now notify about Attachments only
                if([item isKindOfClass:[ZPZoteroAttachment class]] && ! [itemsToBeNotifiedAbout containsObject:parentItem]){
                    [itemsToBeNotifiedAbout addObject:parentItem];
                }
            }
        }
        
        if(![itemsToBeNotifiedAbout containsObject:item]){
            [itemsToBeNotifiedAbout addObject:item];
        }

    }
    
    for(item in itemsToBeNotifiedAbout){
        @synchronized(_itemObservers){
            NSEnumerator* e = [_itemObservers objectEnumerator];
            NSObject* id;
            
            while( id= [e nextObject]) {
                if([(NSObject <ZPItemObserver>*) id respondsToSelector:@selector(notifyItemAvailable:)]){
                    [(NSObject <ZPItemObserver>*) id notifyItemAvailable:item];
                }
            }
        }
    }
}


-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library{
    
    @synchronized(_libraryObservers){

        NSEnumerator* e = [_libraryObservers objectEnumerator];
        NSObject* id;
        
        while( id= [e nextObject]) {
            [(NSObject <ZPLibraryObserver>*) id notifyLibraryWithCollectionsAvailable:library];
        }
    }    
}


-(void) notifyAttachmentDownloadCompleted:(ZPZoteroAttachment*) attachment{
    @synchronized(_attachmentObservers){
        NSEnumerator* e = [_attachmentObservers objectEnumerator];
        NSObject* id;
        
        while( id= [e nextObject]) {
            [(NSObject <ZPAttachmentObserver>*) id notifyAttachmentDownloadCompleted:attachment];
        }
    }
}


//Adds and removes observers
-(void) registerItemObserver:(NSObject<ZPItemObserver>*)observer{
    @synchronized(_itemObservers){
        [_itemObservers addObject:observer];
    }
    
}
-(void) removeItemObserver:(NSObject<ZPItemObserver>*)observer{
    @synchronized(_itemObservers){
        [_itemObservers removeObject:observer];
    }
}

-(void) registerLibraryObserver:(NSObject<ZPLibraryObserver>*)observer{
    @synchronized(_libraryObservers){
        [_libraryObservers addObject:observer];
    }
    
}
-(void) removeLibraryObserver:(NSObject<ZPLibraryObserver>*)observer{
    @synchronized(_libraryObservers){
        [_libraryObservers removeObject:observer];
    }
}



-(void) registerAttachmentObserver:(NSObject<ZPAttachmentObserver>*)observer{
    @synchronized(_attachmentObservers){
        [_attachmentObservers addObject:observer];
    }
}

-(void) removeAttachmentObserver:(NSObject<ZPAttachmentObserver>*)observer{
    @synchronized(_attachmentObservers){
        [_attachmentObservers removeObject:observer];
    }
}



@end
