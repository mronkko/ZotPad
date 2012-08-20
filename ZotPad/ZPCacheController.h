//
//  ZPCache.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPLibraryObserver.h"
#import "ZPAttachmentObserver.h"
#import "ZPZoteroCollection.h"
#import "ZPCacheStatusToolbarController.h"

@interface ZPCacheController : NSObject <ZPLibraryObserver, ZPAttachmentObserver>{
    
    //These two arrays contain a list of IDs/Keys that will be cached
    
    NSMutableDictionary* _itemKeysToRetrieve;
    NSMutableDictionary* _libraryTimestamps;
    
    NSMutableArray* _collectionsToCache;
    NSMutableArray* _librariesToCache;
    NSMutableArray* _filesToDownload;
    NSMutableSet* _attachmentsToUpload;
    
    // An operation que to fetch items in the background
    NSOperationQueue* _serverRequestQueue;

    // Size of the folder in kilo bytes    
    unsigned long long int _sizeOfDocumentsFolder;
    
    ZPCacheStatusToolbarController* _statusView;

}
-(void) setStatusView:(ZPCacheStatusToolbarController*) statusView;

+(ZPCacheController*) instance;


// These methods tell the cache that the user is currently viewing something
//-(void) setCurrentCollection:(NSString*) collectionKey;
//-(void) setCurrentLibrary:(NSInteger) libraryID;
//-(void) setCurrentItem:(NSString*) itemKey;
-(void) updateLibrariesAndCollectionsFromServer;
-(void) updateCollectionsForLibraryFromServer:(ZPZoteroLibrary*) libraryID;
-(void) purgeAllAttachmentFilesFromCache;

-(void) refreshActiveItem:(ZPZoteroItem*) item;
-(void) setActiveLibrary:(NSInteger)libraryID collection:(NSString*)collectionKey;

-(void) addToLibrariesQueue:(ZPZoteroLibrary*)object priority:(BOOL)priority;
-(void) addToCollectionsQueue:(ZPZoteroCollection*)object priority:(BOOL)priority;
-(void) addToItemQueue:(NSArray*)items libraryID:(NSInteger)libraryID priority:(BOOL)priority;
-(void) addAttachmentToUploadQueue:(ZPZoteroAttachment*) attachment withNewFile:(NSURL*)urlToFile; 
-(void) addAttachmentToDowloadQueue:(ZPZoteroAttachment *)attachment;

@end
