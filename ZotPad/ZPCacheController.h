//
//  ZPCache.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPLibraryObserver.h"
#import "ZPAttachmentObserver.h"


@interface ZPCacheController : NSObject <ZPLibraryObserver, ZPAttachmentObserver>{
    
    //These two arrays contain a list of IDs/Keys that will be cached
    
    NSMutableDictionary* _itemKeysToRetrieve;
    NSMutableArray* _containersToCache;
    NSMutableArray* _filesToDownload;
    
    // An operation que to fetch items in the background
    NSOperationQueue* _serverRequestQueue;
    NSOperationQueue* _fileDownloadQueue;

    
    unsigned long long int _sizeOfDocumentsFolder;

}


+(ZPCacheController*) instance;

// Activates the cache controller
-(void) activate;

// These methods tell the cache that the user is currently viewing something
//-(void) setCurrentCollection:(NSString*) collectionKey;
-(void) setCurrentLibrary:(NSNumber*) libraryID;
//-(void) setCurrentItem:(NSString*) itemKey;
-(void) updateLibrariesAndCollectionsFromServer;

-(NSArray*) uncachedItemKeysForLibrary:(NSNumber*) libraryId collection:(NSString*) collectionKey;

@end
