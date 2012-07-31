
//
//  ZPDataLayer.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "ZPDataLayer.h"

//Cache
#import "ZPCacheController.h"

//Server connection
#import "ZPServerConnection.h"
#import "ZPServerResponseXMLParser.h"

//DB and DB library
#import "ZPDatabase.h"




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

- (NSArray*) collectionsForLibrary : (NSNumber*)currentlibraryID withParentCollection:(NSString*)currentcollectionKey {

    [[ZPCacheController instance] performSelectorInBackground:@selector(updateCollectionsForLibraryFromServer:) withObject:[ZPZoteroLibrary dataObjectWithKey:currentlibraryID]];
    return [[ZPDatabase instance] collectionsForLibrary:currentlibraryID withParentCollection:currentcollectionKey];

}



- (NSArray*) getItemKeysFromCacheForLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending{
    
    [[ZPCacheController instance] setActiveLibrary:libraryID collection:collectionKey];
    
    return [[ZPDatabase instance] getItemKeysForLibrary:libraryID collectionKey:collectionKey searchString:searchString orderField:orderField sortDescending:sortDescending];
}



-(void) updateItemDetailsFromServer:(ZPZoteroItem*)item{
    
    [[ZPCacheController instance] refreshActiveItem:item];
}

//These are hard coded for now. 
- (NSArray*) fieldsThatCanBeUsedForSorting{

    return [NSArray arrayWithObjects: @"dateAdded", @"dateModified", @"title", @"creator", @"itemType", @"date", @"publisher", @"publicationTitle", @"journalAbbreviation", @"language", @"accessDate", @"libraryCatalog", @"callNumber", @"rights", nil];
    //These are available through the API, but not used: @"addedBy" @"numItems"
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
                ZPZoteroItem* parentItem = (ZPZoteroItem*) [ZPZoteroItem dataObjectWithKey:parentKey];
                
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
        @synchronized(_itemObservers){
            NSEnumerator* e = [_itemObservers objectEnumerator];
            NSObject* id;
            
            while( id= [e nextObject]) {
                if([(NSObject <ZPItemObserver>*) id respondsToSelector:@selector(notifyItemAvailable:)]){
                    [(NSObject <ZPItemObserver>*) id notifyItemAvailable:item];
                }
            }
        }
        
        [[NSNotificationCenter defaultCenter]
         postNotificationName:@"ItemDataAvailable" 
         object:self
         userInfo:[NSDictionary dictionaryWithObject:item forKey:@"item"]];
    }
}


-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library{
    
    DDLogVerbose(@"New metadata from library %@ is available",library.title);
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
        if([id respondsToSelector:@selector(notifyAttachmentDownloadCompleted:)])
            [(NSObject <ZPAttachmentObserver>*) id notifyAttachmentDownloadCompleted:attachment];
    }
}

-(void) notifyAttachmentDownloadStarted:(ZPZoteroAttachment*) attachment{
    NSEnumerator* e = [_attachmentObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([id respondsToSelector:@selector(notifyAttachmentDownloadStarted:)])
            [(NSObject <ZPAttachmentObserver>*) id notifyAttachmentDownloadStarted:attachment];
    }
}

-(void) notifyAttachmentDownloadFailed:(ZPZoteroAttachment*) attachment withError:(NSError*) error{
    NSEnumerator* e = [_attachmentObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([id respondsToSelector:@selector(notifyAttachmentDownloadFailed:withError:)])
            [(NSObject <ZPAttachmentObserver>*) id notifyAttachmentDownloadFailed:attachment withError:error];
    }
    
}

-(void) notifyAttachmentDeleted:(ZPZoteroAttachment*) attachment fileAttributes:(NSDictionary*) fileAttributes{
    NSEnumerator* e = [_attachmentObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([id respondsToSelector:@selector(notifyAttachmentDeleted:fileAttributes:)])
            [(NSObject <ZPAttachmentObserver>*) id notifyAttachmentDeleted:attachment fileAttributes:fileAttributes];
    }

}

-(void) notifyAttachmentUploadCompleted:(ZPZoteroAttachment*) attachment{
    NSEnumerator* e = [_attachmentObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([id respondsToSelector:@selector(notifyAttachmentUploadCompleted:)])
            [(NSObject <ZPAttachmentObserver>*) id notifyAttachmentUploadCompleted:attachment];
    }
}

-(void) notifyAttachmentUploadStarted:(ZPZoteroAttachment*) attachment{
    NSEnumerator* e = [_attachmentObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([id respondsToSelector:@selector(notifyAttachmentUploadStarted:)])
            [(NSObject <ZPAttachmentObserver>*) id notifyAttachmentUploadStarted:attachment];
    }
}

-(void) notifyAttachmentUploadFailed:(ZPZoteroAttachment*) attachment withError:(NSError*) error{
    NSEnumerator* e = [_attachmentObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([id respondsToSelector:@selector(notifyAttachmentUploadFailed:withError:)])
            [(NSObject <ZPAttachmentObserver>*) id notifyAttachmentUploadFailed:attachment withError:error];
    }
    
}

-(void) notifyAttachmentUploadCanceled:(ZPZoteroAttachment*) attachment {
    NSEnumerator* e = [_attachmentObservers objectEnumerator];
    NSObject* id;
    
    while( id= [e nextObject]) {
        if([id respondsToSelector:@selector(notifyAttachmentUploadCanceled:)])
            [(NSObject <ZPAttachmentObserver>*) id notifyAttachmentUploadCanceled:attachment];
    }
    
}



//Adds and removes observers. Because of concurrency issues we are not using mutable sets here.
-(void) registerItemObserver:(NSObject<ZPItemObserver>*)observer{
    if(observer!=NULL){
        @synchronized(_itemObservers){
            [_itemObservers addObject:observer];
        }
    }
}
-(void) removeItemObserver:(NSObject<ZPItemObserver>*)observer{
    if(observer!=NULL){
        @synchronized(_itemObservers){
            [_itemObservers removeObject:observer];
        }
    }
}

-(void) registerLibraryObserver:(NSObject<ZPLibraryObserver>*)observer{
    if(observer!=NULL){
        _libraryObservers = [_libraryObservers setByAddingObject:observer];
    }
}
-(void) removeLibraryObserver:(NSObject<ZPLibraryObserver>*)observer{
    if(observer!=NULL){
        NSMutableSet* tempSet =[NSMutableSet setWithSet:_libraryObservers];
        [tempSet removeObject:observer];
        _libraryObservers = tempSet;
    }
}


-(void) registerAttachmentObserver:(NSObject<ZPAttachmentObserver>*)observer{
    if(observer!=NULL){
        _attachmentObservers = [_attachmentObservers setByAddingObject:observer];
    }
}

-(void) removeAttachmentObserver:(NSObject<ZPAttachmentObserver>*)observer{
    if(observer!=NULL){
        NSMutableSet* tempSet =[NSMutableSet setWithSet:_attachmentObservers];
        [tempSet removeObject:observer];
        _attachmentObservers = tempSet;
    }
}



@end
