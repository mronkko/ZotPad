//
//  ZPCache.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPLibraryObserver.h"



@interface ZPCacheController : NSObject <ZPLibraryObserver>{
    
    //These two arrays contain a list of IDs/Keys that will be cached
    
    NSMutableArray* _libraryIDsToCache;
    NSMutableArray* _collectionKeysToCache;
    NSMutableArray* _itemKeysForAttachmentsToCache;
    
    NSMutableDictionary* _cacheDataObjects;
    
    // An operation que to fetch items in the background
    NSOperationQueue* _serverRequestQueue;
    NSOperationQueue* _fileDownloadQueue;
    
    
    NSString* _currentlyActiveCollectionKey;
    NSNumber* _currentlyActiveLibraryID;
    
}


+(ZPCacheController*) instance;

// Activates the cache controller
-(void) activate;

// These methods tell the cache that the user is currently viewing something
-(void) setCurrentCollection:(NSString*) collectionKey;
-(void) setCurrentLibrary:(NSNumber*) libraryID;
-(void) setCurrentItem:(NSString*) itemKey;
-(void) updateLibrariesAndCollectionsFromServer;

// Request status of cache
-(NSArray*) cachedItemKeysForCollection:(NSString*)collectionKey libraryID:(NSNumber*)libraryID; 


@end
