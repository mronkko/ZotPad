//
//  ZPCache.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>



#import "ZPCacheStatusToolbarController.h"


@interface ZPCacheController : NSObject{
    
    //These two arrays contain a list of IDs/Keys that will be cached
    
    NSMutableDictionary* _itemKeysToRetrieve;
    NSMutableDictionary* _libraryTimestamps;
    
    NSMutableArray* _collectionsToCache;
    NSMutableArray* _librariesToCache;
    NSMutableArray* _filesToDownload;
    NSMutableSet* _attachmentsToUpload;
    
    // Size of the folder in kilo bytes    
    unsigned long long int _sizeOfDocumentsFolder;
    
}

+(ZPCacheController*) instance;

- (void) setStatusView:(ZPCacheStatusToolbarController*)statusView;


//Metadata

-(void) refreshActiveItem:(ZPZoteroItem*) item;
-(void) setActiveLibrary:(NSInteger)libraryID collection:(NSString*)collectionKey;

-(void) addToLibrariesQueue:(ZPZoteroLibrary*)object priority:(BOOL)priority;
-(void) addToCollectionsQueue:(ZPZoteroCollection*)object priority:(BOOL)priority;
-(void) addToItemQueue:(NSArray*)items libraryID:(NSInteger)libraryID priority:(BOOL)priority;

//Attachments
-(void) purgeAllAttachmentFilesFromCache;
-(void) addAttachmentToUploadQueue:(ZPZoteroAttachment*) attachment withNewFile:(NSURL*)urlToFile;
-(void) addAttachmentToDowloadQueue:(ZPZoteroAttachment *)attachment;

//Call backs
-(void) processNewItemsFromServer:(NSArray*)items forLibraryID:(NSInteger)libraryID;
-(void) processNewLibrariesFromServer:(NSArray*)items;
-(void) processNewCollectionsFromServer:(NSArray*)items forLibraryID:(NSInteger)libraryID;
-(void) processNewItemKeyListFromServer:(NSArray*)items forLibraryID:(NSInteger) libraryID;
-(void) processNewTopLevelItemKeyListFromServer:(NSArray*)items userInfo:(NSDictionary*)parameters;
-(void) processNewTimeStampForLibrary:(NSInteger)libraryID collection:(NSString*)key timestampValue:(NSString*)value;

@end
