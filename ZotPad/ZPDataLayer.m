
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




//Private methods 

@interface ZPDataLayer ();

//Retrieves 50 items at a time from the server, called from getItemKeysForView and executed as operation
- (void) _doAdHocItemRetrieval:(NSArray*) targetItemKeyArray;
//Gets one item details and writes these to the database
-(void) _updateItemDetailsFromServer:(ZPZoteroItem*) item;
    


@end


@implementation ZPDataLayer


static ZPDataLayer* _instance = nil;


-(id)init
{
    self = [super init];
    
    _debugDataLayer = TRUE;
        
    _itemObservers = [[NSMutableSet alloc] initWithCapacity:2];
    _libraryObservers = [[NSMutableSet alloc] initWithCapacity:3];
    _attachmentObservers = [[NSMutableSet alloc] initWithCapacity:2];
    
    _serverRequestQueue = [[NSOperationQueue alloc] init];
    
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
    return [[ZPDatabase instance] getItemKeysForLibrary:libraryID collection:collectionKey searchString:searchString orderField:orderField sortDescending:sortDescending];
}

- (NSArray*) getItemKeysFromServerForLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending{

    [[ZPCacheController instance] setCurrentLibrary:libraryID];
    [[ZPCacheController instance] setCurrentCollection:collectionKey];
    
    //Reset the ad hoc itemlist
    _adHocItemKeys = NULL;
    
        
    //If there is no search or sort condition, we can reuse the item retrieval operations from cache controller
    if(searchString == NULL && orderField == NULL){
        return [[ZPCacheController instance] cachedItemKeysForCollection:collectionKey libraryID:libraryID];
    }
    
    else{
        //Do add hoc retrieve that is not stored in cache 
        _adHocItemKeys = [NSMutableArray array];
        _adHocItemKeysOffset=0;
        
        _adHocCollectionKey=collectionKey;
        _adHocLibraryID=libraryID;
        _adHocOrderField=orderField;
        _adHocSearchString=searchString;
        _adHocSortDescending=sortDescending;
        
        [self queueAdHocItemRetrieval];
        return _adHocItemKeys;
    }

}



/*
 
 Retrieves item details from the server and writes them in the database in the background
 
 */

-(void) queueAdHocItemRetrieval{
    
    NSInvocationOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                                    selector:@selector(_doAdHocItemRetrieval:) object:_adHocItemKeys];
    
    [_serverRequestQueue addOperation:retrieveOperation];
}

- (void) _doAdHocItemRetrieval:(NSMutableArray*) targetItemKeyArray{
 
    
    //Retrieve initial 15 items
    
    ZPServerResponseXMLParser* parserResults = [[ZPServerConnection instance] retrieveItemsFromLibrary:_adHocLibraryID collection:_adHocCollectionKey 
                                                                                          searchString:_adHocSearchString orderField:_adHocOrderField
                                                                                        sortDescending:_adHocSortDescending limit:15+(_adHocItemKeysOffset>0)*35 start:_adHocItemKeysOffset getItemDetails:TRUE];
    //If we are still showing this list, process the results
    if(targetItemKeyArray==_adHocItemKeys && parserResults!=NULL){
        
        //If the ad hoc array is empty, fill it with appropriate number of nulls
        if([targetItemKeyArray count] ==0){
            for(NSInteger i=0;i<[parserResults totalResults];++i){
                [targetItemKeyArray addObject:[NSNull null]];
            }
        }
        for(ZPZoteroItem* item in [parserResults parsedElements]){
            [[ZPDatabase instance] addItemToDatabase:item];
            [targetItemKeyArray replaceObjectAtIndex:_adHocItemKeysOffset withObject:item];
            _adHocItemKeysOffset++;

        }
        [self notifyItemKeyArrayUpdated:_adHocItemKeys];
        //If there is more data coming, que a new retrieval
        if(_adHocItemKeysOffset<[parserResults totalResults] & targetItemKeyArray==_adHocItemKeys) [self queueAdHocItemRetrieval];
    }

}

- (ZPZoteroItem*) getItemByKey: (NSString*) key{
    
    return [[ZPDatabase instance] getItemByKey:key];
}


-(void) updateItemDetailsFromServer:(ZPZoteroItem*)item{
    
    NSInvocationOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                                    selector:@selector(_updateItemDetailsFromServer:) object:item];
  
    [_serverRequestQueue addOperation:retrieveOperation];
}

-(void) _updateItemDetailsFromServer:(ZPZoteroItem*)item{
    item = [[ZPServerConnection instance] retrieveSingleItemDetailsFromServer:item];
    [[ZPDatabase instance] writeItemFieldsToDatabase:item];
    [[ZPDatabase instance] writeItemCreatorsToDatabase:item];
    
    for(ZPZoteroAttachment* attachment in item.attachments){
        [[ZPDatabase instance] addAttachmentToDatabase:attachment];
    }
    for(ZPZoteroNote* note in item.notes){
        [[ZPDatabase instance] addNoteToDatabase:note];
    }
    
    
    [self notifyItemDetailsAvailable:item];

}

-(void) notifyItemKeyArrayUpdated:(NSArray*)itemKeyArray{

    NSEnumerator* e = [_itemObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([(NSObject <ZPItemObserver>*) id respondsToSelector:@selector(notifyItemKeyArrayUpdated:)]){
            [(NSObject <ZPItemObserver>*) id notifyItemKeyArrayUpdated:itemKeyArray];
        }
    }

}

//Notifies all observers that a new item is available
-(void) notifyItemBasicsAvailable:(ZPZoteroItem*)item{

    NSEnumerator* e = [_itemObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([(NSObject <ZPItemObserver>*) id respondsToSelector:@selector(notifyItemBasicsAvailable:)]){
            [(NSObject <ZPItemObserver>*) id notifyItemBasicsAvailable:item];
        }
    }
}

//Notifies all observers that a new item is available
-(void) notifyItemDetailsAvailable:(ZPZoteroItem*)item{
    
    NSEnumerator* e = [_itemObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([(NSObject <ZPItemObserver>*) id respondsToSelector:@selector(notifyItemDetailsAvailable:)]){
            [(NSObject <ZPItemObserver>*) id notifyItemDetailsAvailable:item];
        }
    }
}

-(void) notifyItemAttachmentsAvailable:(ZPZoteroItem*)item{
    
    NSEnumerator* e = [_itemObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([(NSObject <ZPItemObserver>*) id respondsToSelector:@selector(notifyItemAttachmentsAvailable:)]){
            [(NSObject <ZPItemObserver>*) id notifyItemAttachmentsAvailable:item];
        }
    }
}


-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library{
    NSEnumerator* e = [_libraryObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        [(NSObject <ZPLibraryObserver>*) id notifyLibraryWithCollectionsAvailable:library];
    }
    
}


-(void) notifyAttachmentDownloadCompleted:(ZPZoteroAttachment*) attachment{
    NSEnumerator* e = [_attachmentObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        [(NSObject <ZPAttachmentObserver>*) id notifyAttachmentDownloadCompleted:attachment];
    }
    
}


//Adds and removes observers
-(void) registerItemObserver:(NSObject<ZPItemObserver>*)observer{
    [_itemObservers addObject:observer];
    
}
-(void) removeItemObserver:(NSObject<ZPItemObserver>*)observer{
    [_itemObservers removeObject:observer];
}

-(void) registerLibraryObserver:(NSObject<ZPLibraryObserver>*)observer{
    [_libraryObservers addObject:observer];
    
}
-(void) removeLibraryObserver:(NSObject<ZPLibraryObserver>*)observer{
    [_libraryObservers removeObject:observer];
}



-(void) registerAttachmentObserver:(NSObject<ZPAttachmentObserver>*)observer{
    [_attachmentObservers addObject:observer];
}

-(void) removeAttachmentObserver:(NSObject<ZPAttachmentObserver>*)observer{
    [_attachmentObservers removeObject:observer];
}



@end
