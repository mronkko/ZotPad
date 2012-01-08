
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


//Private methods 

@interface ZPDataLayer ();

//Gets one item details and writes these to the database
-(void) _updateItemDetailsFromServer:(ZPZoteroItem*) item;


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
    [[ZPCacheController instance] setCurrentLibrary:libraryID];
    return [[ZPDatabase instance] getItemKeysForLibrary:libraryID collection:collectionKey searchString:searchString orderField:orderField sortDescending:sortDescending];
}




- (ZPZoteroItem*) getItemByKey: (NSString*) key{
    
    ZPZoteroItem* item=[[ZPDatabase instance] getItemByKey:key];
    [[ZPDatabase instance] addAttachmentsToItem:item];
    return item;
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
    
    
    [self notifyItemAvailable:item];

}




//Notifies all observers that a new item is available
-(void) notifyItemAvailable:(ZPZoteroItem*)item{
    
    NSEnumerator* e = [_itemObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([(NSObject <ZPItemObserver>*) id respondsToSelector:@selector(notifyItemAvailable:)]){
            [(NSObject <ZPItemObserver>*) id notifyItemAvailable:item];
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
