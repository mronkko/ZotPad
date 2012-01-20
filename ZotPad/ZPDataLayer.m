
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



- (NSArray*) getItemKeysFromCacheForLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending{
    
    [[ZPCacheController instance] setActiveLibrary:libraryID collection:collectionKey];
    
    return [[ZPDatabase instance] getItemKeysForLibrary:libraryID collectionKey:collectionKey searchString:searchString orderField:orderField sortDescending:sortDescending];
}



-(void) updateItemDetailsFromServer:(ZPZoteroItem*)item{
    
    [[ZPCacheController instance] refreshActiveItem:item];
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
            NSEnumerator* e = [_itemObservers objectEnumerator];
            NSObject* id;
            
            while( id= [e nextObject]) {
                if([(NSObject <ZPItemObserver>*) id respondsToSelector:@selector(notifyItemAvailable:)]){
                    [(NSObject <ZPItemObserver>*) id notifyItemAvailable:item];
                }
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


//Adds and removes observers. Because of concurrency issues we are not using mutable sets here.
-(void) registerItemObserver:(NSObject<ZPItemObserver>*)observer{
    _itemObservers = [_itemObservers setByAddingObject:observer];
    
}
-(void) removeItemObserver:(NSObject<ZPItemObserver>*)observer{
    NSMutableSet* tempSet =[NSMutableSet setWithSet:_itemObservers];
    [tempSet removeObject:observer];
    _itemObservers = tempSet;
}

-(void) registerLibraryObserver:(NSObject<ZPLibraryObserver>*)observer{
    _libraryObservers = [_libraryObservers setByAddingObject:observer];
}
-(void) removeLibraryObserver:(NSObject<ZPLibraryObserver>*)observer{
    NSMutableSet* tempSet =[NSMutableSet setWithSet:_libraryObservers];
    [tempSet removeObject:observer];
    _libraryObservers = tempSet;
}


-(void) registerAttachmentObserver:(NSObject<ZPAttachmentObserver>*)observer{
    _attachmentObservers = [_attachmentObservers setByAddingObject:observer];
}

-(void) removeAttachmentObserver:(NSObject<ZPAttachmentObserver>*)observer{
    NSMutableSet* tempSet =[NSMutableSet setWithSet:_attachmentObservers];
    [tempSet removeObject:observer];
    _attachmentObservers = tempSet;
}



@end
