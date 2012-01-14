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
#import "ZPLogger.h"

#define NUMBER_OF_ITEMS_TO_RETRIEVE 50


@interface ZPCacheController (){
    NSNumber* _activeLibraryID;
    NSString* _activeCollectionKey;
    NSString* _activeItemKey;
}

-(void) _checkQueues;
-(void) _checkMetadataQueue;
-(void) _checkDownloadQueue;

-(void) _addToContainerQueue:(NSObject*)object priority:(BOOL)priority;
-(void) _addToItemQueue:(NSArray*)items libraryID:(NSNumber*)libraryID priority:(BOOL)priority;

-(void) _doItemRetrieval:(NSArray*) itemKeys fromLibrary:(NSNumber*)libraryID;

-(void) _cacheItemIfNeeded:(ZPZoteroItem*) item;

//Gets one item details and writes these to the database
-(void) _updateItemDetailsFromServer:(ZPZoteroItem*) item;

-(void) _checkIfContainerNeedsCacheRefreshAndQueue:(NSNumber*) libraryID collectionKey:(NSString*)collectionKey;
-(void) _checkIfAttachmentExistsAndQueueForDownload:(ZPZoteroAttachment*)attachment;

//TODO: refactor this method
-(void) _checkIfAttachmenstExistAndQueueForDownload:(NSArray*)parentKeys;

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
    [_fileDownloadQueue  setMaxConcurrentOperationCount:2];
    
    //These collections contain things that we need to cache. These have been checked so that we know that they are either missing or outdated
    
    _itemKeysToRetrieve = [[NSMutableDictionary alloc] init];
    _containersToCache = [[NSMutableArray alloc] init];
    _filesToDownload = [[NSMutableArray alloc] init];
    
    //Register as observer so that we can follow the size of the cache
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

}

/*
 
 Checks if there are things to cache and starts processing these if there is something to retrieve.
 
*/

-(void) _checkQueues{

    [self _checkDownloadQueue];
    [self _checkMetadataQueue];
}

-(void) _checkDownloadQueue{
    @synchronized(_fileDownloadQueue){
        while([_fileDownloadQueue operationCount] < [_fileDownloadQueue maxConcurrentOperationCount] && [_filesToDownload count] >0){
            ZPZoteroAttachment* attachment = [_filesToDownload objectAtIndex:0];
            [_filesToDownload removeObjectAtIndex:0];
            NSLog(@"Queueing download %@ files in queue %i", attachment.attachmentTitle ,[_filesToDownload count]);
            NSOperation* downloadOperation = [[NSInvocationOperation alloc] initWithTarget:[ZPServerConnection instance] selector:@selector(downloadAttachment:) object:attachment];
            
            [_fileDownloadQueue addOperation:downloadOperation];
        }        
    }
    
}

-(void) _checkMetadataQueue{
    
    @synchronized(_serverRequestQueue){
        while([_serverRequestQueue operationCount] <= [_serverRequestQueue maxConcurrentOperationCount]){
            
            
            //Choose the queue the active library or choose a first non-empty queue
            NSMutableArray* keyArray = [_itemKeysToRetrieve objectForKey:_activeLibraryID];
            NSEnumerator* e = [_itemKeysToRetrieve keyEnumerator];
            NSNumber* libraryID = _activeLibraryID;
            
            while((keyArray == NULL || [keyArray count]==0) && (libraryID = [e nextObject])) keyArray = [_itemKeysToRetrieve objectForKey:keyArray];
            
            //If we found a non-empty que, queue item retrival
            if(keyArray != NULL && [keyArray count]>0){
                NSArray* keysToRetrieve;
                @synchronized(keyArray){
                    NSRange range = NSMakeRange(0, MIN(50,[keyArray count]));
                    keysToRetrieve = [keyArray subarrayWithRange:range];
                    
                    //Remove the items that we are retrieving
                    [keyArray removeObjectsInRange:range];
                }
                
                //Create an invocation
                SEL selector = @selector(_doItemRetrieval:fromLibrary:);
                NSMethodSignature* signature = [[self class] instanceMethodSignatureForSelector:selector];
                NSInvocation* invocation  = [NSInvocation invocationWithMethodSignature:signature];
                [invocation setTarget:self];
                [invocation setSelector:selector];
                
                //Set arguments
                [invocation setArgument:&keysToRetrieve atIndex:2];
                [invocation setArgument:&libraryID atIndex:3];
                
                //Create operation and queue it for background retrieval
                NSOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithInvocation:invocation];
                [_serverRequestQueue addOperation:retrieveOperation];
                
            }
            
            
            //If there are no items, start retrieving collection memberships
            else if([_containersToCache count]>0){
                
                NSOperation* retrieveOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(_doContainerRetrieval:) object:[_containersToCache objectAtIndex:0]];
                
                //Remove the items that we are retrieving
                [_containersToCache removeObjectAtIndex:0];
                
                [_serverRequestQueue addOperation:retrieveOperation];
                
            } 
            else break;
            
        }
    }
}


- (void) _doItemRetrieval:(NSArray*) itemKeys fromLibrary:(NSNumber*)libraryID{
    
    NSLog(@"Retrieving items %@",[itemKeys componentsJoinedByString:@", "]);
    
    
    NSArray* items = [[ZPServerConnection instance] retrieveItemsFromLibrary:libraryID itemKeys:itemKeys];
    
    for (ZPZoteroItem* item in items) {
        [self _cacheItemIfNeeded:item];
    }

    [self _checkQueues];
}

-(void) _cacheItemIfNeeded:(ZPZoteroItem*) item{
    

    //Do this with synchronization to avoid using too much CPU by attempting to run this in parallel
    @synchronized(self){
        
        if(! [item needsToBeWrittenToCache]) return;
        
        [item clearNeedsToBeWrittenToCache];
        
        //If this is an attachement item, store the attachment information
        
        if([item isKindOfClass:[ZPZoteroAttachment class]]){       
            ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) item;
            //For now we only deal with attachment files, not attachment links.
            if(attachment.attachmentURL != NULL){
                [[ZPDatabase instance] addAttachmentToDatabase:attachment];
                [self _checkIfAttachmentExistsAndQueueForDownload:attachment];
            }
            //Standalone attachments
            if(attachment.parentItemKey==attachment.key){
                [[ZPDatabase instance] addItemToDatabase:attachment];
            }
            
        }
        //If this is a note item, store the note information
        else if([item isKindOfClass:[ZPZoteroNote class]]){
            ZPZoteroNote* note = (ZPZoteroNote*) item;
            [[ZPDatabase instance] addNoteToDatabase:note];
            
            //Standalone notes
            if(note.parentItemKey==note.key){
                [[ZPDatabase instance] addItemToDatabase:note];
            }
            
        }
        //Normal item
        else{
            if(item.creators ==NULL) [NSException raise:@"Creators cannot be null" format:@"Attempted to write an item (%@) with null creators to database. This is most likely a bug in API response parser."];
            if(item.fields ==NULL || [item.fields count]==0) [NSException raise:@"Fields cannot be null or empty" format:@"Attempted to write an item (%@) with null or empty fields to database. This is most likely a bug in API response parser."];
            [[ZPDatabase instance] addItemToDatabase:item];
            [[ZPDatabase instance] writeItemFieldsToDatabase:item];
            [[ZPDatabase instance] writeItemCreatorsToDatabase:item];
        }
        
        [[ZPDataLayer instance] notifyItemAvailable:item];
    }
}

/*
 
 Retrieves container memberships. This does not automatically queue items retrievals because
 all items will be retieved for libraries anyway based on the date modified.
 
 */

- (void) _doContainerRetrieval:(NSObject*) container{
    
    //Is it a library or a collection
    NSString* collectionKey = NULL;
    NSNumber* libraryID = NULL;
    if([container isKindOfClass:[ZPZoteroLibrary class]]){
        libraryID = [(ZPZoteroLibrary*)container libraryID];
    }
    else{
        libraryID = [(ZPZoteroCollection*)container libraryID];
        collectionKey = [(ZPZoteroCollection*)container collectionKey];
    }
    
    NSArray* itemKeys = [[ZPServerConnection instance] retrieveKeysInContainer:libraryID collectionKey:collectionKey];

    // for(NSString* itemKey in itemKeys) [self _checkIfItemDoesNotExistInCacheAndQueue:itemKey fromLibrary:libraryID];
        
    
    if(collectionKey==NULL){
        [[ZPDatabase instance] deleteItemsNotInArray:itemKeys fromLibrary:libraryID]; 

        //Get non-existing items
        //NSArray* noteAndAttachmentKeys = [[ZPServerConnection instance] retrieveNoteAndAttachmentKeysFromLibrary:libraryID];
        //for(NSString* itemKey in noteAndAttachmentKeys) [self _checkIfItemDoesNotExistInCacheAndQueue:itemKey fromLibrary:libraryID];
        
        //Get items that have the timestamp set to later than the modification time of this library.
        NSString* lastTimestamp = [ZPZoteroLibrary ZPZoteroLibraryWithID:libraryID].lastCompletedCacheTimestamp;
        
        //Retrieve items as long as we have items that have time stamp greater than this timestamp
        NSInteger offset=0;
        while(TRUE){
            NSArray* items= [[ZPServerConnection instance] retrieveItemsFromLibrary:libraryID limit:NUMBER_OF_ITEMS_TO_RETRIEVE offset:offset];
            for(ZPZoteroItem* item in items){
                if(lastTimestamp==NULL || 
                   [lastTimestamp compare: item.lastTimestamp] == NSOrderedAscending){
                    [self _cacheItemIfNeeded:item];   
                }
                else goto outer;
            }
            if([items count] < NUMBER_OF_ITEMS_TO_RETRIEVE ) goto outer;
            offset = offset + NUMBER_OF_ITEMS_TO_RETRIEVE;
        }
    outer:; 
        
        [[ZPDatabase instance] setUpdatedTimestampForLibrary:libraryID toValue:[[ZPServerConnection instance] retrieveTimestampForContainer:libraryID collectionKey:NULL]];
        
            
    }
    else{
        [[ZPDatabase instance] removeItemsNotInArray:itemKeys fromCollection:collectionKey inLibrary:libraryID]; 
        [[ZPDatabase instance] setUpdatedTimestampForCollection:collectionKey toValue:[[ZPServerConnection instance] retrieveTimestampForContainer:libraryID collectionKey:collectionKey]];
    }

    [self _checkQueues];
}

-(void) refreshActiveItem:(ZPZoteroItem*) item {
    if(item == NULL) [NSException raise:@"Item cannot be null" format:@"Method refresh active item was called with an argument that was null."];
    [self performSelectorInBackground:@selector(_updateItemDetailsFromServer:) withObject:item];
    
}

-(void) _updateItemDetailsFromServer:(ZPZoteroItem*)item{
    
    _activeItemKey = item.key;
    
    item = [[ZPServerConnection instance] retrieveSingleItemDetailsFromServer:item];
    [self _cacheItemIfNeeded:item];
    
    for(ZPZoteroAttachment* attachment in item.attachments){
        [self _cacheItemIfNeeded:attachment];
    }
    for(ZPZoteroNote* note in item.notes){
        [self _cacheItemIfNeeded:note];
    }
    
    
    [[ZPDataLayer instance] notifyItemAvailable:item];
    
}



-(NSArray*) uncachedItemKeysForLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending{

    
    //First get the list of items in this item list

    NSMutableArray* itemKeys = [NSMutableArray arrayWithArray:[[ZPServerConnection instance] retrieveKeysInContainer:libraryID collectionKey:collectionKey searchString:searchString orderField:orderField sortDescending:sortDescending]];
    
    //Remove items that we have in the cache
    
    //TODO: refactor this into a more logical place

    if(! [libraryID isEqual:_activeLibraryID] && ! [[ZPPreferences instance] cacheAttachmentsAllLibraries] ){
        [_filesToDownload removeAllObjects];
        NSLog(@"Clearing download queue because library changed and preferences do not indicate that all libraries should be downloaded");
    }
    
    //Store the libraryID and collectionKEy
    _activeLibraryID = libraryID;
    
    //Both keys might be null, so we need to compare equality directly as well
    if(! (collectionKey == _activeCollectionKey || [collectionKey isEqual:_activeCollectionKey]) && ! [[ZPPreferences instance] cacheAttachmentsActiveLibrary]){
        [_filesToDownload removeAllObjects];
        NSLog(@"Clearing download queue because collection changed and preferences do not indicate that all collections should be downloaded");
    }
    _activeCollectionKey = collectionKey;
    
    //Queue everything that we have for this library / collection for download
    
    if([[ZPPreferences instance] cacheAttachmentsActiveCollection]){
        [self performSelectorInBackground:@selector(_checkIfAttachmenstExistAndQueueForDownload:) withObject:[NSArray arrayWithArray:itemKeys]];
    }
     
     
    //End of part that needs to be refactored
    
    NSArray* cachedKeys = [[ZPDatabase instance] getItemKeysForLibrary:libraryID collectionKey:collectionKey searchString:searchString orderField:orderField sortDescending:sortDescending];
    
    [itemKeys removeObjectsInArray:cachedKeys];
    
    //Add this into the queue if there are any uncached items
    if([itemKeys count]>0){
        [self _addToItemQueue:itemKeys libraryID:libraryID priority:YES];
        if(collectionKey!=NULL) [self _addToContainerQueue:[ZPZoteroCollection ZPZoteroCollectionWithKey:collectionKey]  priority:YES];
        else [self _addToContainerQueue:[ZPZoteroLibrary ZPZoteroLibraryWithID: libraryID] priority:YES];
    }

    [self _checkQueues];

    return itemKeys;
}

-(void) _checkIfAttachmenstExistAndQueueForDownload:(NSArray*)parentKeys{
    //These have already been checked to not have downloaded files and have been sorted by priority

    for(NSString* key in parentKeys){
        ZPZoteroItem* item = [ZPZoteroItem retrieveOrInitializeWithKey:key];
        for(ZPZoteroAttachment* attachment in item.attachments){
            [self _checkIfAttachmentExistsAndQueueForDownload:attachment];
        }    
    }
}

-(void) _checkIfAttachmentExistsAndQueueForDownload:(ZPZoteroAttachment*)attachment{
    
    if(! attachment.fileExists){
        BOOL doCache=false;
        //Cache based on preferences
        if([[ZPPreferences instance] cacheAttachmentsAllLibraries]){
            doCache = true;
        }
        else if([[ZPPreferences instance] cacheAttachmentsActiveLibrary]){
            doCache = (attachment.libraryID == _activeLibraryID);
            
        }
        else if([[ZPPreferences instance] cacheAttachmentsActiveCollection]){
            if([[ZPZoteroItem retrieveOrInitializeWithKey:attachment.parentItemKey].libraryID isEqualToNumber:_activeLibraryID] && _activeCollectionKey == NULL){
                doCache=true;
            }
            else if([[ZPDatabase instance] doesItemKey:attachment.parentItemKey belongToCollection:_activeCollectionKey]){
                doCache = true;
            }
        }
        else if([[ZPPreferences instance] cacheAttachmentsActiveItem]){
            doCache =( attachment.parentItemKey == _activeItemKey);
        }
        
        if(doCache){
            [_filesToDownload removeObject:attachment];
            [_filesToDownload insertObject:attachment atIndex:0];
            NSLog(@"Queuing attachment download to %@, number of files in queue %i",attachment.fileSystemPath,[_filesToDownload count]);

            [self _checkQueues];
        }
    }
}

-(void) _addToContainerQueue:(NSObject*)object priority:(BOOL)priority{
    if(priority){
        [_containersToCache removeObject:object];
        [_containersToCache insertObject:object atIndex:0];
    }
    else if(! [_containersToCache containsObject:object]){
        [_containersToCache addObject:object];
    }
}

-(void) _addToItemQueue:(NSArray*)itemKeys libraryID:(NSNumber*)libraryID priority:(BOOL)priority{

    NSMutableArray* targetArray = [_itemKeysToRetrieve objectForKey:libraryID];
    if(targetArray == NULL){
        targetArray = [NSMutableArray array];
        [_itemKeysToRetrieve setObject:targetArray forKey:libraryID];               
    }
    
    @synchronized(targetArray){
        if(priority){
            [targetArray removeObjectsInArray:itemKeys];
            [targetArray insertObjects:itemKeys atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,[itemKeys count])]];
        }
        else{
            NSMutableArray* checkedKeys= [NSMutableArray arrayWithArray: itemKeys];
            [checkedKeys removeObjectsInArray:targetArray];
            [targetArray addObjectsFromArray:checkedKeys];
        }
    }
}

-(void) _checkIfContainerNeedsCacheRefreshAndQueue:(NSNumber*) libraryID collectionKey:(NSString*)collectionKey{
    
    //Get the time stamp to see if we need to retrieve more
    
    NSString* timestamp = [[ZPServerConnection instance] retrieveTimestampForContainer:libraryID collectionKey:collectionKey];

    
    if(timestamp != NULL){
        
        ZPZoteroItemContainer* container;
        
        if(collectionKey == NULL){
            container = [ZPZoteroLibrary ZPZoteroLibraryWithID:libraryID];
        }
        else{
            container = [ZPZoteroCollection ZPZoteroCollectionWithKey:collectionKey];
        }

    
        if(![timestamp isEqualToString:container.lastCompletedCacheTimestamp]){
        
            [self _addToContainerQueue:container priority:FALSE];
            
            if(collectionKey == NULL && [[ZPPreferences instance] cacheMetadataActiveLibrary]){
                
                //Retrieve all collections for this library and add them to cache
                for(ZPZoteroCollection* collection in [[ZPDatabase instance] allCollectionsForLibrary:container.libraryID]){
                    [self _checkIfContainerNeedsCacheRefreshAndQueue:collection.libraryID collectionKey:collection.collectionKey];
                }
            }
            [self _checkQueues];
        }
    }
}

    
-(void) updateLibrariesAndCollectionsFromServer{
         
    //My library  
    NSArray* collections = [[ZPServerConnection instance] retrieveCollectionsForLibraryFromServer:[NSNumber numberWithInt:1]];
    if(collections!=NULL){
        [[ZPDatabase instance] addOrUpdateCollections:collections forLibrary:[NSNumber numberWithInt:1]];
        [[ZPDataLayer instance] notifyLibraryWithCollectionsAvailable:[ZPZoteroLibrary ZPZoteroLibraryWithID:[NSNumber numberWithInt:1]]];
    }
    
    NSLog(@"Loading group library information from server");
    NSArray* libraries = [[ZPServerConnection instance] retrieveLibrariesFromServer];
    if(libraries==NULL) return;
    
    [[ZPDatabase instance] addOrUpdateLibraries:libraries];
    
    NSEnumerator* e = [libraries objectEnumerator];
    
    ZPZoteroLibrary* library;
    
    while ( library = (ZPZoteroLibrary*) [e nextObject]) {
        
        collections = [[ZPServerConnection instance] retrieveCollectionsForLibraryFromServer:library.libraryID];
        if(collections==NULL) return;
        
        [[ZPDatabase instance] addOrUpdateCollections:collections forLibrary:library.libraryID];
        
        [[ZPDataLayer instance] notifyLibraryWithCollectionsAvailable:library];
        
    }
    
}




-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library{
    if([[ZPPreferences instance] cacheMetadataAllLibraries]){
        [self _checkIfContainerNeedsCacheRefreshAndQueue:library.libraryID collectionKey:NULL];
        [self _checkQueues];
    }
}




#pragma mark -
#pragma mark Attachment cache


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
        NSInteger temp = _sizeOfDocumentsFolder/1048576;
        [defaults setObject:[NSString stringWithFormat:@"%i MB",temp] forKey:@"cachesizecurrent"];
        
    }
    else{
        float temp = ((float)_sizeOfDocumentsFolder)/1073741824;
        [defaults setObject:[NSString stringWithFormat:@"%.1f GB",temp] forKey:@"cachesizecurrent"];
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
        
        _sizeOfDocumentsFolder = _sizeOfDocumentsFolder + attachment.attachmentLength;

        NSLog(@"Cache size after adding %@ to cache is %i",attachment.fileSystemPath,_sizeOfDocumentsFolder);

        if(_sizeOfDocumentsFolder>=[[ZPPreferences instance] maxCacheSize]) [self _cleanUpCache];
        [self _updateCacheSizePreference];
    }
}

- (void) _cleanUpCache{
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    NSArray* paths = [[ZPDatabase instance] getCachedAttachmentPaths];

    //Delete orphaned files
    
    NSString* _documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_documentsDirectory error:NULL];
    
    
    for (NSString* _documentFilePath in directoryContent) {
        NSString* path = [_documentsDirectory stringByAppendingPathComponent:_documentFilePath];

        if(![paths containsObject:path] && ! [path hasSuffix:@"zotpad.sqlite"] && ! [path hasSuffix:@"zotpad.sqlite-journal"]){
            NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES];
            _sizeOfDocumentsFolder -= [_documentFileAttributes fileSize];
            NSLog(@"Deleting orphaned file %@ cache size now %i",path,_sizeOfDocumentsFolder);
            [[NSFileManager defaultManager] removeItemAtPath:path error: NULL];
        }
    }
    
    //Delete attachment files until the size of the cache is below the maximum size
    NSString* path;
    for(path in paths){
        NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES];
        _sizeOfDocumentsFolder -= [_documentFileAttributes fileSize];
        [[NSFileManager defaultManager] removeItemAtPath:path error: NULL];
        NSLog(@"Deleting old file to reclaim space %@ cache size now %i",path,_sizeOfDocumentsFolder);
        if (_sizeOfDocumentsFolder<=[[ZPPreferences instance] maxCacheSize]) break;
    }

}


@end
