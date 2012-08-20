//
//  ZPDataLayer.h
//  ZotPad
//
//  This class takes care of managing the cache and coordinating data request from the UI.
//
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPCore.h"

#import "ZPItemListViewController.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroAttachment.h"
#import "ZPItemObserver.h"
#import "ZPLibraryObserver.h"
#import "ZPAttachmentObserver.h"
#import "ZPZoteroLibrary.h"
#import "ZPZoteroCollection.h"

@interface ZPDataLayer : NSObject{
    
    
    //These sets are immutable due to concurrency issues
    NSMutableSet* _itemObservers;
    NSMutableSet* _libraryObservers;
    NSMutableSet* _attachmentObservers;
    
    //Queue for ad hoc retrievals
    NSOperationQueue* _serverRequestQueue;
    
}

// This class is used as a singleton
+ (ZPDataLayer*) instance;

// Methods for explicitly requesting updated data from server
-(void) updateItemDetailsFromServer:(ZPZoteroItem*)item;

// Methods for retrieving data from the data layer
- (NSArray*) libraries;
- (NSArray*) collectionsForLibrary : (NSInteger)currentlibraryID withParentCollection:(NSString*)currentCollectionKey;
- (NSArray*) getItemKeysFromCacheForLibrary:(NSInteger)libraryID collection:(NSString*)collectionKey
                        searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending;

- (NSArray*) fieldsThatCanBeUsedForSorting;

//TODO: refactornorifications http://stackoverflow.com/questions/2191594/how-to-send-and-receive-message-through-nsnotificationcenter-in-objective-c

//Adds and removes observers
-(void) registerItemObserver:(NSObject<ZPItemObserver>*)observer;
-(void) removeItemObserver:(NSObject<ZPItemObserver>*)observer;

-(void) registerLibraryObserver:(NSObject<ZPLibraryObserver>*)observer;
-(void) removeLibraryObserver:(NSObject<ZPLibraryObserver>*)observer;

-(void) registerAttachmentObserver:(NSObject<ZPAttachmentObserver>*)observer;
-(void) removeAttachmentObserver:(NSObject<ZPAttachmentObserver>*)observer;


//Notifies all observers that a new data are available
-(void) notifyItemsAvailable:(NSArray*)items;

-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library;

-(void) notifyAttachmentDownloadCompleted:(ZPZoteroAttachment*) attachment;
-(void) notifyAttachmentDownloadStarted:(ZPZoteroAttachment*) attachment;
-(void) notifyAttachmentDownloadFailed:(ZPZoteroAttachment*) attachment withError:(NSError*) error;
-(void) notifyAttachmentDeleted:(ZPZoteroAttachment*) attachment fileAttributes:(NSDictionary*) fileAttributes;

-(void) notifyAttachmentUploadCompleted:(ZPZoteroAttachment*) attachment;
-(void) notifyAttachmentUploadFailed:(ZPZoteroAttachment*) attachment withError:(NSError*) error;
-(void) notifyAttachmentUploadStarted:(ZPZoteroAttachment*) attachment;
-(void) notifyAttachmentUploadCanceled:(ZPZoteroAttachment*) attachment;



@end
