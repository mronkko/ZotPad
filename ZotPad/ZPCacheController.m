//
//  ZPCache.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPCacheController.h"
#import "ZPPreferences.h"
#import "ZPDataLayer.h"
#import "ZPDatabase.h"
#import "ZPServerResponseXMLParser.h"
#import "ZPServerConnection.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroItemContainer.h"
#import "ZPZoteroAttachment.h"
#import "ZPZoteroNote.h"

#define NUMBER_OF_ITEMS_TO_RETRIEVE 50
#define NUMBER_OF_ITEMS_NOT_YET_KNOWN -1

//This is a helper class for cache controller

@interface ZPCacheControllerData : NSObject <NSCopying> {
    NSMutableArray* itemKeys;
    NSInteger offset;
    NSInteger totalItems;
    NSNumber* libraryID;
    NSString* collectionKey;
    NSString* updatedTimestamp;
}
@property (retain) NSString* collectionKey;
@property (retain) NSString* updatedTimestamp;
@property (retain) NSNumber* libraryID;
@property (retain) NSMutableArray* itemKeys;
@property NSInteger offset;
@property NSInteger totalItems;

- (id)copyWithZone:(NSZone*)zone;

@end

@implementation ZPCacheControllerData 

@synthesize updatedTimestamp;
@synthesize collectionKey;
@synthesize libraryID;
@synthesize itemKeys;
@synthesize offset;
@synthesize totalItems;

- (id) init{
    self= [super init];
    totalItems =  NUMBER_OF_ITEMS_NOT_YET_KNOWN;
    return self;
}

- (id)copyWithZone:(NSZone *)zone{
    ZPCacheControllerData* copy = [[ZPCacheControllerData alloc] init];
    copy.itemKeys = itemKeys;
    copy.offset = offset;
    copy.totalItems = totalItems;
    copy.libraryID = libraryID;
    copy.collectionKey = collectionKey;
    copy.updatedTimestamp = updatedTimestamp;
    
    return copy;
}

@end


@interface ZPCacheController (){
    NSMutableArray* _currentlyActiveRetrievals;
}

-(void) _checkQueues;
-(void) _checkMetadataQueue;
-(void) _checkDownloadQueue;
-(BOOL) _checkIfNeedsMoreItemsAndQueue:(NSObject*) key;
-(void) _doItemRetrieval:(ZPCacheControllerData*) data;
-(void) _checkIfCacheRefreshNeededAndQueue:(ZPCacheControllerData*)data;

-(ZPCacheControllerData*) _cacheControllerDataObjectForZoteroItemContainer:(ZPZoteroItemContainer*)object;

-(void) _cleanUpCompletedWithKey:(NSObject*)key;
-(void) _updateLibrariesAndCollectionsFromServer;
-(void) _checkIfExistsAndQueueForDownload:(ZPZoteroAttachment*)attachment;

- (void) _doNoteAndAttachmentRetrieval:(ZPCacheControllerData*)data;


- (unsigned long long int) _documentsFolderSize;
- (void) _scanAndSetSizeOfDocumentsFolder;
- (void) _updateCacheSizePreference;
- (void) _cleanUpCache;
- (void) _updateCacheSizeAfterAddingAttachment:(ZPZoteroAttachment*)attachment;

@end

@implementation ZPCacheController


static ZPCacheController* _instance = nil;


-(id)init
{
    self = [super init];
    
    
    //Initialize OperationQueues for retrieving data from server and writing it to cache
    _serverRequestQueue = [[NSOperationQueue alloc] init];
    [_serverRequestQueue setMaxConcurrentOperationCount:4];

    _fileDownloadQueue  = [[NSOperationQueue alloc] init];
    [_fileDownloadQueue  setMaxConcurrentOperationCount:1];
    
    //These two arrays contain a list of IDs/Keys that will be cached. They have been already checked so that we know that recaching is needed
    
    _libraryIDsToCache = [[NSMutableArray alloc] init];
    _collectionKeysToCache = [[NSMutableArray alloc] init];
    
    _filesToDownload = [[NSMutableArray alloc] init];
    
    
    _cacheDataObjects = [[NSMutableDictionary alloc] init];

    
    _currentlyActiveRetrievals = [NSMutableArray arrayWithCapacity:10];
    
    [[ZPDataLayer instance] registerAttachmentObserver:self];
    
    _sizeOfDocumentsFolder = 0;
    [self performSelectorInBackground:@selector(_scanAndSetSizeOfDocumentsFolder) withObject:NULL];
	
    
    return self;
}

/*
 Singleton accessor
 */

+(ZPCacheController*) instance {
    if(_instance == NULL){
        _instance = [[ZPCacheController alloc] init];
    }
    return _instance;
}

-(void) activate{
    
    [[ZPDataLayer instance] registerLibraryObserver:self];

    //Set up initial retrievals
    [self updateLibrariesAndCollectionsFromServer];
    
   

}

/*
 
 Checks if there are things to cache and starts processing these if there is something to retrieve.
 
*/

-(void) _checkQueues{
    [self _checkDownloadQueue];
    [self _checkMetadataQueue];
}

-(void) _checkDownloadQueue{
    @synchronized(self){
        if([_fileDownloadQueue operationCount] < 2 && [_filesToDownload count] > 0){
            ZPZoteroAttachment* attachment = [_filesToDownload objectAtIndex:0];
            [_filesToDownload removeObjectAtIndex:0];
            
            NSOperation* downloadOperation = [[NSInvocationOperation alloc] initWithTarget:[ZPServerConnection instance]                                                                                         selector:@selector(downloadAttachment:) object:attachment];
            
            [_fileDownloadQueue addOperation:downloadOperation];
            
        }
    }
}

-(void) _checkMetadataQueue{
    
    @synchronized(self){
        if([_serverRequestQueue operationCount] <= [_serverRequestQueue maxConcurrentOperationCount]){
            
            BOOL retrieving = FALSE;
            
            //If we have root of a library visible, prioritize it 
            if(_currentlyActiveLibraryID !=NULL && _currentlyActiveCollectionKey == NULL && [_libraryIDsToCache containsObject:_currentlyActiveLibraryID]){
                retrieving =  ([self _checkIfNeedsMoreItemsAndQueue:_currentlyActiveLibraryID]);             
            }
            
            //Otherwise, prioritize the visible collection 
            if(! retrieving && _currentlyActiveCollectionKey !=NULL && [_collectionKeysToCache containsObject:_currentlyActiveCollectionKey]){
                retrieving =  ([self _checkIfNeedsMoreItemsAndQueue:_currentlyActiveCollectionKey]);
            }
            
            //If the active views do not have items to retrieve, retrieve items for the first library in the queue
            
            
            if(! retrieving) for(NSObject* key in _libraryIDsToCache){
                if ([self _checkIfNeedsMoreItemsAndQueue:key]){
                    retrieving = TRUE;
                    break;
                }
            }
            
            if(! retrieving) for(NSObject* key in _collectionKeysToCache){
                if ([self _checkIfNeedsMoreItemsAndQueue:key]){
                    retrieving = TRUE;
                    break;
                }
            }
            
            
            
            //Check if we can schedule a new operation immediately.
            if(retrieving) [self _checkQueues];
            
        }
    }
}

/*
 Cheks if more items are needed for a container, and if so, queues a new retrieval and updates offset
 */

-(BOOL) _checkIfNeedsMoreItemsAndQueue:(NSObject*) key{


    //Only one retrieval at a time
    if([_currentlyActiveRetrievals containsObject:key]) return false;

    ZPCacheControllerData* data = [_cacheDataObjects objectForKey:key];
    

    if((data.offset < data.totalItems) || (data.totalItems == NUMBER_OF_ITEMS_NOT_YET_KNOWN)){
        
        
        [_currentlyActiveRetrievals addObject:key];
        NSOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self                                                                                           selector:@selector(_doItemRetrieval:) object:[data copyWithZone:NULL]];

        [_serverRequestQueue addOperation:retrieveOperation];
        
        data.offset=data.offset+NUMBER_OF_ITEMS_TO_RETRIEVE;
        
        if((data.offset >= data.totalItems) && (data.totalItems != NUMBER_OF_ITEMS_NOT_YET_KNOWN)) [self _cleanUpCompletedWithKey:key];

        return true;
    }
    else{
        //The script should basically never get here. This clean up is just in case. There is no ocasion that it should be called
        [self _cleanUpCompletedWithKey:key];
        return false;
    }
}

-(void)_cleanUpCompletedWithKey:(NSObject*)key{
    ZPCacheControllerData* data = [_cacheDataObjects objectForKey:key];
    [_cacheDataObjects removeObjectForKey:key];
    if(data.collectionKey != NULL) [_collectionKeysToCache removeObject:data.collectionKey];
    else [_libraryIDsToCache removeObject:data.libraryID];
}

- (void) _doItemRetrieval:(ZPCacheControllerData*)data{
    
    //If the libraryID is not in the list of things that we still need to cache, it means that all items from this library
    //have been cached. In this case we just need to retrieve item IDs and no item details at all
    
    BOOL libraryCacheIsNotComplete = [_libraryIDsToCache containsObject:data.libraryID] || data.collectionKey==NULL;
    
    ZPServerResponseXMLParser* parserResults = [[ZPServerConnection instance] retrieveItemsFromLibrary:data.libraryID collection:data.collectionKey
                                                                                          searchString:NULL orderField:NULL
                                                                                        sortDescending:FALSE limit:NUMBER_OF_ITEMS_TO_RETRIEVE
                                                                                                 start:data.offset getItemDetails:libraryCacheIsNotComplete];

    //Mark that this is no longer retrieving data
    if(data.collectionKey == NULL)
        [_currentlyActiveRetrievals removeObject:data.libraryID];
    else
        [_currentlyActiveRetrievals removeObject:data.collectionKey];
        
    //Only process on response at a time
    
   
    @synchronized(self){
        
        NSAssert(data.updatedTimestamp != NULL, @"Timestamp must be set prior to retrieving data into cache");
        NSAssert(data.totalItems != NUMBER_OF_ITEMS_NOT_YET_KNOWN, @"Number of items must be set prior to retrieving data into cache");

        
        for (ZPZoteroItem* item in [parserResults parsedElements]) {
            
            
            [[ZPDatabase instance] addItemToDatabase:item];
            if(data.collectionKey!=NULL){
                [[ZPDatabase instance] addItem:item toCollection:data.collectionKey];
            }
            
            [data.itemKeys replaceObjectAtIndex:data.offset withObject:item.key];
            data.offset++;
        }
        
        
        //Notify the UI that the item list has changed
        [[ZPDataLayer instance] notifyItemKeyArrayUpdated:data.itemKeys];
        
        //Is the container now completely cached? 
        if([data.itemKeys lastObject] != [NSNull null]){
            if(data.collectionKey==NULL){
                [[ZPDatabase instance] deleteItemsNotInArray:data.itemKeys fromLibrary:data.libraryID]; 
                [[ZPDatabase instance] setUpdatedTimestampForLibrary:data.libraryID toValue:data.updatedTimestamp];
                
                //Start retrieving of attachments and notes. These are not tracked but just run in the background.
                
                ZPServerResponseXMLParser* parser = [[ZPServerConnection instance] retrieveNotesAndAttachmentsFromLibrary:data.libraryID limit:1 start:0];
                
                if([parser totalResults] >0 ){
                    
                    data.updatedTimestamp = [parser updateTimestamp];
                    data.totalItems = [parser totalResults];
                    data.offset=0;
                    data.itemKeys = NULL;
                    
                    NSOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                                          selector:@selector(_doNoteAndAttachmentRetrieval:) object:data];
                    
                    [_serverRequestQueue addOperation:retrieveOperation];
                }
                

                
            }
            else{
                [[ZPDatabase instance] removeItemsNotInArray:data.itemKeys fromCollection:data.collectionKey inLibrary:data.libraryID]; 
                [[ZPDatabase instance] setUpdatedTimestampForCollection:data.collectionKey toValue:data.updatedTimestamp];
            }
            
        }
    }
    
    [self _checkQueues];
}

- (void) _doNoteAndAttachmentRetrieval:(ZPCacheControllerData*)data{
    
    
    ZPServerResponseXMLParser* parserResults = [[ZPServerConnection instance] retrieveNotesAndAttachmentsFromLibrary:data.libraryID limit:NUMBER_OF_ITEMS_TO_RETRIEVE
                                                                                                 start:data.offset];
    
    
    for (NSObject* object in [parserResults parsedElements]) {
        
        if([object isKindOfClass:[ZPZoteroAttachment class]]){       
            ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) object;
            //For now we only deal with attachment files, not attachment links.
            if(attachment.attachmentURL != NULL){
                [[ZPDatabase instance] addAttachmentToDatabase:attachment];
                [self _checkIfExistsAndQueueForDownload:attachment];
            }
        }
        else if([object isKindOfClass:[ZPZoteroNote class]]){         
            [[ZPDatabase instance] addNoteToDatabase:(ZPZoteroNote*) object];
        }
        else NSAssert(TRUE,@"Unknown attachment item type");

            
        data.offset++;
    }
    
    
    if(data.offset<[parserResults totalResults]){
        NSOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                          selector:@selector(_doNoteAndAttachmentRetrieval:) object:data];
    
        [_serverRequestQueue addOperation:retrieveOperation];
    }
    
    [self _checkQueues];
}

-(void) _checkIfExistsAndQueueForDownload:(ZPZoteroAttachment*)attachment{
    //Check if the file exists
    if (![[NSFileManager defaultManager] fileExistsAtPath:[attachment fileSystemPath]]){
        [_filesToDownload addObject:attachment]; 
    }
    
}

-(void) _checkIfCacheRefreshNeededAndQueue:(ZPCacheControllerData*) data{
    
    //Get the first item from the container and compare the time stamp to see if we need to retrieve more
    
    ZPServerResponseXMLParser* parser = [[ZPServerConnection instance] retrieveItemsFromLibrary:data.libraryID collection:data.collectionKey searchString:NULL orderField:NULL sortDescending:FALSE limit:1 start:0  getItemDetails:FALSE];

    
    if([parser totalResults] >0 ){
        
        
        ZPZoteroItemContainer* container;
        
        if(data.collectionKey == NULL){
            container = [ZPZoteroLibrary ZPZoteroLibraryWithID:data.libraryID];
        }
        else{
            container = [ZPZoteroCollection ZPZoteroCollectionWithKey:data.collectionKey];
        }

        ZPZoteroItem* item = [parser.parsedElements objectAtIndex:0];
    
        if(! [item.lastTimestamp isEqualToString:container.lastCompletedCacheTimestamp]){
        
            data.updatedTimestamp = item.lastTimestamp;
            data.totalItems = [parser totalResults];
            data.offset=0;
            
            while([data.itemKeys count]< data.totalItems){
                [data.itemKeys addObject:[NSNull null]];
            }
            
            if(data.collectionKey == NULL){
                [_libraryIDsToCache insertObject:data.libraryID atIndex:0];
                [_cacheDataObjects setObject:data forKey:data.libraryID];
            }
            else{
                [_collectionKeysToCache insertObject:data.collectionKey atIndex:0];
                [_cacheDataObjects setObject:data forKey:data.collectionKey];
            }
            
            [self _checkQueues];
        }
    }
}

/*
 
 This is called
 
 */

-(ZPCacheControllerData*) _cacheControllerDataObjectForZoteroItemContainer:(ZPZoteroItemContainer*)object{
    
    ZPCacheControllerData* data = [[ZPCacheControllerData alloc] init];
    data.libraryID = [object libraryID];
    data.collectionKey = [object collectionKey];
    data.itemKeys = [NSMutableArray array];
    
    return data;
}
    
    
-(void) updateLibrariesAndCollectionsFromServer{
    NSInvocationOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                                    selector:@selector(_updateLibrariesAndCollectionsFromServer) object:NULL];
    [_serverRequestQueue addOperation:retrieveOperation];
    NSLog(@"Opertions in queue %i",[_serverRequestQueue operationCount]);
}

/*
 Updates the local cache for libraries and collections and retrieves this data from the server
 */


-(void) _updateLibrariesAndCollectionsFromServer{
    
    
    NSLog(@"Loading group library information from server");
    NSArray* libraries = [[ZPServerConnection instance] retrieveLibrariesFromServer];
    if(libraries==NULL) return;
    
    ZPZoteroLibrary* myLibrary = [ZPZoteroLibrary ZPZoteroLibraryWithID:[NSNumber numberWithInt:1]];

    libraries=[libraries arrayByAddingObject:myLibrary];
    
    [[ZPDatabase instance] addOrUpdateLibraries:libraries];
    
    NSEnumerator* e = [libraries objectEnumerator];
    
    ZPZoteroLibrary* library;
    
    while ( library = (ZPZoteroLibrary*) [e nextObject]) {
        
        NSArray* collections = [[ZPServerConnection instance] retrieveCollectionsForLibraryFromServer:library.libraryID];
        if(collections==NULL) return;
        
        [[ZPDatabase instance] addOrUpdateCollections:collections forLibrary:library.libraryID];
        
        [[ZPDataLayer instance] notifyLibraryWithCollectionsAvailable:library];
        
    }
    
}

-(void) setCurrentCollection:(NSString*) collectionKey{
    _currentlyActiveCollectionKey = collectionKey;
}

-(void) setCurrentLibrary:(NSNumber*) libraryID{
    _currentlyActiveLibraryID = libraryID;
}

-(void) setCurrentItem:(NSString*) itemKey{
    //TODO: Implement. This should affect the attachment downloading priority
}



-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library{
    
    if([[ZPPreferences instance] cacheAllLibraries]){
        if(! ([library.serverTimestamp isEqualToString: library.lastCompletedCacheTimestamp ] || 
              [_libraryIDsToCache containsObject:[library libraryID]])){
                        
            [self _checkIfCacheRefreshNeededAndQueue:[self _cacheControllerDataObjectForZoteroItemContainer:library]];
            
            //Retrieve all collections for this library and add them to cache
            for(ZPZoteroCollection* collection in [[ZPDatabase instance] allCollectionsForLibrary:library.libraryID]){
                
                if (! ([collection.serverTimestamp isEqualToString:collection.lastCompletedCacheTimestamp] || 
                       [_collectionKeysToCache containsObject:[collection collectionKey]])){
                    [self _checkIfCacheRefreshNeededAndQueue:[self _cacheControllerDataObjectForZoteroItemContainer:collection]];
                }
            }
        }
    }
}


/*
 
 
 */

-(NSArray*) cachedItemKeysForCollection:(NSString*)collectionKey libraryID:(NSNumber*)libraryID {
 
    NSObject* key;
    if(collectionKey==NULL){
        key= libraryID;
    }
    else{
        key= collectionKey;
    }
    
    ZPCacheControllerData* data =[_cacheDataObjects objectForKey:key];
    
    if(data == NULL){
        NSMutableArray* ret = [NSMutableArray array];
        data=[[ZPCacheControllerData alloc] init];
        [_cacheDataObjects setObject:data forKey:key];
        data.itemKeys = ret;
        data.libraryID = libraryID;
        data.collectionKey = collectionKey;

        [ _serverRequestQueue addOperation: [[NSInvocationOperation alloc] initWithTarget:self
                                              selector:@selector(_checkIfCacheRefreshNeededAndQueue:) object:data]];
        return ret;
    }
    else return [data itemKeys];
    
}

-(void) notifyAttachmentDownloadCompleted:(ZPZoteroAttachment*) attachment{
    [self _updateCacheSizeAfterAddingAttachment:attachment];
    [self _checkQueues];
}


- (void) _scanAndSetSizeOfDocumentsFolder{
    _sizeOfDocumentsFolder = [self _documentsFolderSize];
    
    [self _updateCacheSizePreference];
}

- (void) _updateCacheSizePreference{
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    //Smaller than one gigabyte
    if(_sizeOfDocumentsFolder < 1073741824){
        float temp = _sizeOfDocumentsFolder/1048576;
        [defaults setObject:[NSString stringWithFormat:@"%i MB",temp] forKey:@"cachesizecurrent"];
        
    }
    else{
        NSString* temp = [NSString stringWithFormat:@".1f",_sizeOfDocumentsFolder/1073741824];
        [defaults setObject:[NSString stringWithFormat:@"%@ GB",temp] forKey:@"cachesizecurrent"];
    }
    
}

/*
 
 Source: http://stackoverflow.com/questions/2188469/calculate-the-size-of-a-folder
 
 */

- (unsigned long long int) _documentsFolderSize {

    NSString* _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_documentsDirectory error:NULL];

    unsigned long long int _documentsFolderSize = 0;
    
    for (NSString* _documentFilePath in directoryContent) {
        NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:[_documentsDirectory stringByAppendingPathComponent:_documentFilePath] traverseLink:YES];
        _documentsFolderSize += [_documentFileAttributes fileSize];
    }
    
    return _documentsFolderSize;
}

- (void) _updateCacheSizeAfterAddingAttachment:(ZPZoteroAttachment*)attachment{
    if(_sizeOfDocumentsFolder!=0){
        
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSInteger maxCacheSize = [[defaults objectForKey:@"cachesizemax"] intValue];
        _sizeOfDocumentsFolder = _sizeOfDocumentsFolder + attachment.attachmentLength;
        if(_sizeOfDocumentsFolder>=maxCacheSize) [self _cleanUpCache];
        [self _updateCacheSizePreference];
    }
}

- (void) _cleanUpCache{
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    float maxCacheSize = [[defaults objectForKey:@"cachesizemax"] floatValue] * 1073741824;

    //Delete attachment files until the size of the cache is below the maximum size
    while(_sizeOfDocumentsFolder>=maxCacheSize){
        ZPZoteroAttachment* attachment = [[ZPDatabase instance] getOldestCachedAttachment];
        [[NSFileManager defaultManager] removeItemAtPath: [attachment fileSystemPath] error: NULL];
        _sizeOfDocumentsFolder = _sizeOfDocumentsFolder - attachment.attachmentLength;
    }

}


@end
