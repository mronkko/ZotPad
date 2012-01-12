//
//  ZPDataLayer.h
//  ZotPad
//
//  This class takes care of managing the cache and coordinating data request from the UI.
//
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPDetailedItemListViewController.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroAttachment.h"
#import "ZPItemObserver.h"
#import "ZPLibraryObserver.h"
#import "ZPAttachmentObserver.h"
#import "ZPZoteroLibrary.h"
#import "ZPZoteroCollection.h"

@interface ZPDataLayer : NSObject {
    
    
    NSMutableSet* _itemObservers;
    NSMutableSet* _libraryObservers;
    NSMutableSet* _attachmentObservers;
    
    //Queut for ad hoc retrievals
    NSOperationQueue* _serverRequestQueue;
    
}

// This class is used as a singleton
+ (ZPDataLayer*) instance;

// Methods for explicitly requesting updated data from server
-(void) updateItemDetailsFromServer:(ZPZoteroItem*)item;

// Methods for retrieving data from the data layer
- (NSArray*) libraries;
- (NSArray*) collectionsForLibrary : (NSNumber*)currentLibraryID withParentCollection:(NSString*)currentCollectionKey;
- (NSArray*) getItemKeysFromCacheForLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey
                        searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending;




//Adds and removes observers
-(void) registerItemObserver:(NSObject<ZPItemObserver>*)observer;
-(void) removeItemObserver:(NSObject<ZPItemObserver>*)observer;

-(void) registerLibraryObserver:(NSObject<ZPLibraryObserver>*)observer;
-(void) removeLibraryObserver:(NSObject<ZPLibraryObserver>*)observer;

-(void) registerAttachmentObserver:(NSObject<ZPAttachmentObserver>*)observer;
-(void) removeAttachmentObserver:(NSObject<ZPAttachmentObserver>*)observer;


//Notifies all observers that a new data are available
-(void) notifyItemAvailable:(ZPZoteroItem*)item;
-(void) notifyItemAttachmentsAvailable:(ZPZoteroItem*)item;

-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library;

-(void) notifyAttachmentDownloadCompleted:(ZPZoteroAttachment*) attachment;




@end
