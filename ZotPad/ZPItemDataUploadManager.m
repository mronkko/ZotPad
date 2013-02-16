//
//  ZPItemDataUploadManager.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 1/5/13.
//
//

#import "ZPCore.h"
#import "ZPItemDataUploadManager.h"
#import "ZPServerConnection.h"

@interface ZPItemDataUploadManager ()

+(BOOL) _uploadCollections;
+(BOOL) _uploadAddItemsToCollections;
+(BOOL) _uploadRemoveItemsFromCollections;
+(BOOL) _uploadAttachmentNotes;
+(BOOL) _uploadNotes;
+(BOOL) _uploadTags;

@end


@implementation ZPItemDataUploadManager

//TODO: refactor this into ZPZoteroServerConnection
#define NUMBER_OF_PARALLEL_REQUESTS 9

+(void) setStatusView:(ZPCacheStatusToolbarController*)statusView{
}

+(void)initialize{
    
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyUserInterfaceAvailable:)
                                                 name:ZPNOTIFICATION_USER_INTERFACE_AVAILABLE
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(notifyUserInterfaceAvailable:)
                                                 name:ZPNOTIFICATION_INTERNET_CONNECTION_AVAILABLE
                                               object:nil];
    
}

+(void)notifyUserInterfaceAvailable:(NSNotification*)notification{
    [self uploadMetadata];
}

/*
 
 Scans for locally modified metadata and uploads it.
 
 */

+(void) uploadMetadata{
    
    // This does only one upload at a time because we have no reliable way of knowing which items are currently uploading
    
    if([ZPServerConnection numberOfActiveMetadataWriteRequests] == 0){
    
        [self _uploadCollections] ||
        [self _uploadAttachmentNotes] ||
        [self _uploadNotes] ||
        [self _uploadTags] ||
        [self _uploadRemoveItemsFromCollections] ||
        [self _uploadAddItemsToCollections];

    }
}

+(BOOL) _uploadCollections{
    
    NSArray* locallyModifiedCollections = [ZPDatabase locallyAddedCollections];
    
    if(locallyModifiedCollections.count >0 ){
        ZPZoteroCollection* locallyAddedCollection = [locallyModifiedCollections objectAtIndex:0];
        [ZPServerConnection createCollection:locallyAddedCollection completion:^(ZPZoteroCollection* serverVersionOfCollection) {

            [ZPDatabase replaceLocallyAddedCollection:locallyAddedCollection withServerVersion:serverVersionOfCollection];
            
            // Notify that the collections have been updated
            [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_LIBRARY_WITH_COLLECTIONS_AVAILABLE object:[ZPZoteroLibrary libraryWithID:serverVersionOfCollection.libraryID]];
            
            NSLog(@"Created collection %@", locallyAddedCollection.title);
            
            // Proceed with other uploads
            [self uploadMetadata];
        }];
        return TRUE;
    }
    else{
        return FALSE;
    }
}

+(BOOL) _uploadAttachmentNotes{
    
    NSArray* locallyEditedAttachments = [ZPDatabase locallyEditedAttachments];
    
    if(locallyEditedAttachments.count >0 ){
        ZPZoteroAttachment* locallyEditedAttachment = [locallyEditedAttachments objectAtIndex:0];
        [ZPServerConnection editAttachment:locallyEditedAttachment completion:^(ZPZoteroAttachment* attachment) {
            
            DDLogInfo(@"Saved updated attachment note (%@) to Zotero server",attachment.key);
            
            [ZPDatabase writeAttachments:[NSArray arrayWithObject:attachment] checkTimestamp:NO];
            [ZPDatabase clearLocalEditFlagsForTagsWithItemKey:attachment.itemKey];
            
            locallyEditedAttachment.etag = attachment.etag;
            locallyEditedAttachment.serverTimestamp = attachment.serverTimestamp;
            
            // Proceed with other uploads
            [self uploadMetadata];
        } conflict:^{
            DDLogWarn(@"Version conflict editing attachment %@",locallyEditedAttachment.title);
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc] initWithTitle:@"Version conflict"
                                           message:[NSString stringWithFormat:@"Your edits to the attachment note (\"%@\") have been canceled because the attachment (%@) has changed on the server.",locallyEditedAttachment.title, locallyEditedAttachment.note]
                                          delegate:nil
                                 cancelButtonTitle:@"OK"
                                 otherButtonTitles:nil] show];
            });
            [ZPDatabase writeAttachments:[NSArray arrayWithObject:locallyEditedAttachment] checkTimestamp:NO];
            
        }];
        return TRUE;
    }
    else{
        return FALSE;
    }
}

+(BOOL) _uploadNotes{

    NSArray* locallyAddedNotes = [ZPDatabase locallyAddedNotes];
    
    if(locallyAddedNotes.count >0 ){
        ZPZoteroNote* locallyAddedNote = [locallyAddedNotes objectAtIndex:0];
        [ZPServerConnection createNote:locallyAddedNote completion:^(ZPZoteroNote* note) {

            DDLogInfo(@"Created a note (%@) on the Zotero server",note.itemKey);
            
            //Add the server version in DB and delete the local version
            [ZPDatabase writeNotes:[NSArray arrayWithObject:note] checkTimestamp:NO];
            [ZPDatabase deleteNote:locallyAddedNote];
            
            //Replace the local version with server version in the parent item notes array
            ZPZoteroItem* parent = [ZPZoteroItem itemWithKey:locallyAddedNote.parentKey];
            
            NSMutableArray* noteArray = [NSMutableArray arrayWithArray:parent.notes];
            
            NSInteger indexOfLocallyAddedNote = [noteArray indexOfObject:locallyAddedNote];
            if(indexOfLocallyAddedNote != NSNotFound){
                [noteArray replaceObjectAtIndex:indexOfLocallyAddedNote withObject:note];
                parent.notes = noteArray;
            }
            
            // Proceed with other uploads
            [self uploadMetadata];
        }];
        return TRUE;
    }
    else{
        NSArray* locallyEditedNotes = [ZPDatabase locallyEditedNotes];
        
        if(locallyEditedNotes.count >0 ){
            ZPZoteroNote* locallyEditedNote = [locallyEditedNotes objectAtIndex:0];
            [ZPServerConnection editNote:locallyEditedNote completion:^(ZPZoteroNote* note) {

                DDLogInfo(@"Edited a note (%@) on the Zotero server", note.itemKey);
                [ZPDatabase writeNotes:[NSArray arrayWithObject:note] checkTimestamp:NO];

                // Proceed with other uploads
                [self uploadMetadata];
            } conflict:^{
                DDLogWarn(@"Version conflict editing note %@",locallyEditedNote.title);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[[UIAlertView alloc] initWithTitle:@"Version conflict"
                                                message:[NSString stringWithFormat:@"Your edits to a note (\"%@\") have been canceled because the note has been modified on the server.", locallyEditedNote.note]
                                               delegate:nil
                                      cancelButtonTitle:@"OK"
                                      otherButtonTitles:nil] show];
                });
                [ZPDatabase writeNotes:[NSArray arrayWithObject:locallyEditedNote] checkTimestamp:NO];
                
            }];
            return TRUE;
        }
        else{
            NSArray* locallyDeletedNotes = [ZPDatabase locallyDeletedNotes];
            
            if(locallyDeletedNotes.count >0 ){
                ZPZoteroNote* locallyDeletedNote = [locallyDeletedNotes objectAtIndex:0];
                [ZPServerConnection deleteNote:locallyDeletedNote completion:^{
                    
                    DDLogInfo(@"Deleted a note (%@) from the Zotero server", locallyDeletedNote.itemKey);
                    [ZPDatabase deleteNote:locallyDeletedNote];

                    // Proceed with other uploads
                    [self uploadMetadata];
                } conflict:^{
                    DDLogWarn(@"Version conflict deleting note %@",locallyDeletedNote.title);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[[UIAlertView alloc] initWithTitle:@"Version conflict"
                                                    message:[NSString stringWithFormat:@"Deleting a note (\"%@\") has been canceled because the note has been modified on the server.",locallyDeletedNote.title]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil] show];
                    });
                    [ZPDatabase writeNotes:[NSArray arrayWithObject:locallyDeletedNote] checkTimestamp:NO];
                    
                }];
                return TRUE;
            }
            else{
                return FALSE;
            }
        }
    }

}

//TODO: Refactor this so that there is only one check for tags

+(BOOL) _uploadTags{

    NSArray* itemsWithLocallyEditedTags = [ZPDatabase itemsWithLocallyEditedTags];
    
    if(itemsWithLocallyEditedTags.count >0 ){
        ZPZoteroItem* itemWithLocallyEditedTags = [itemsWithLocallyEditedTags objectAtIndex:0];
        [ZPServerConnection editItem:itemWithLocallyEditedTags completion:^(ZPZoteroItem* item) {
            
            [ZPDatabase writeItems:[NSArray arrayWithObject:item] checkTimestamp:NO];
            [ZPDatabase clearLocalEditFlagsForTagsWithItemKey:item.itemKey];

            DDLogInfo(@"Update tags for item %@",item.itemKey);
            
            // Proceed with other uploads
            [self uploadMetadata];
        } conflict:^{
            DDLogWarn(@"Version conflict when uploading tags for item %@. Uploading tags is postponed until the updated version of the item is received from the server.",itemWithLocallyEditedTags.itemKey);
            [ZPServerConnection retrieveItemsFromLibrary:itemWithLocallyEditedTags.libraryID itemKeys:[NSArray arrayWithObject:itemWithLocallyEditedTags.itemKey]];

        }];
        return TRUE;
    }
    else{
        NSArray* attachmentsWithLocallyEditedTags = [ZPDatabase attachmentsWithLocallyEditedTags];
        
        if(attachmentsWithLocallyEditedTags.count >0 ){
            ZPZoteroAttachment* attachmentWithLocallyEditedTags = [attachmentsWithLocallyEditedTags objectAtIndex:0];
            [ZPServerConnection editAttachment:attachmentWithLocallyEditedTags completion:^(ZPZoteroAttachment* attachment) {
                
                [ZPDatabase writeAttachments:[NSArray arrayWithObject:attachment] checkTimestamp:NO];
                [ZPDatabase clearLocalEditFlagsForTagsWithItemKey:attachment.itemKey];

                DDLogInfo(@"Update tags for attachment %@",attachment.itemKey);
                
                // Proceed with other uploads
                [self uploadMetadata];
            } conflict:^{
                DDLogWarn(@"Version conflict when uploading tags for attachment %@. Uploading tags is postponed until the updated version of the attachment is received from the server.",attachmentWithLocallyEditedTags.itemKey);
                [ZPServerConnection retrieveItemsFromLibrary:attachmentWithLocallyEditedTags.libraryID itemKeys:[NSArray arrayWithObject:attachmentWithLocallyEditedTags.itemKey]];

            }];
            return TRUE;
        }
        else{
            NSArray* notesWithLocallyEditedTags = [ZPDatabase notesWithLocallyEditedTags];
            
            if(notesWithLocallyEditedTags.count >0 ){
                ZPZoteroNote* noteWithLocallyEditedTags = [notesWithLocallyEditedTags objectAtIndex:0];
                [ZPServerConnection editNote:noteWithLocallyEditedTags completion:^(ZPZoteroNote* note) {
                    
                    [ZPDatabase writeNotes:[NSArray arrayWithObject:note] checkTimestamp:NO];
                    [ZPDatabase clearLocalEditFlagsForTagsWithItemKey:note.itemKey];
                    
                    DDLogInfo(@"Update tags for note %@",note.itemKey);

                    // Proceed with other uploads
                    [self uploadMetadata];
                } conflict:^{
                    DDLogWarn(@"Version conflict when uploading tags for note %@. Uploading tags is postponed until the updated version of the note is received from the server.",noteWithLocallyEditedTags.itemKey);
                    [ZPServerConnection retrieveItemsFromLibrary:noteWithLocallyEditedTags.libraryID itemKeys:[NSArray arrayWithObject:noteWithLocallyEditedTags.itemKey]];
                }];
                return TRUE;
            }
            else{
                return FALSE;
            }
        }
    }
}

+(BOOL) _uploadAddItemsToCollections{
    NSDictionary* locallyModifiedCollectionMemberships = [ZPDatabase locallyAddedCollectionMemberships];
    
    if(locallyModifiedCollectionMemberships.count >0 ){
        NSString* collectionKey = [locallyModifiedCollectionMemberships.keyEnumerator nextObject];
        NSArray* itemKeys = [locallyModifiedCollectionMemberships objectForKey:collectionKey];

        ZPZoteroCollection* collection = [ZPZoteroCollection collectionWithKey:collectionKey];

        [ZPServerConnection addItems:itemKeys toCollection:[ZPZoteroCollection collectionWithKey:collectionKey] completion:^{
            
            [ZPDatabase addItemKeys:itemKeys toCollection:collectionKey];

            DDLogInfo(@"Added %i item(s) to collection %@",[itemKeys count], collection.title);

            // Proceed with other uploads
            [self uploadMetadata];
        }];
        return TRUE;
    }
    else{
        return FALSE;
    }
}

+(BOOL) _uploadRemoveItemsFromCollections{

    NSDictionary* locallyModifiedCollectionMemberships = [ZPDatabase locallyDeletedCollectionMemberships];
    
    if(locallyModifiedCollectionMemberships.count >0 ){
        NSString* collectionKey = [locallyModifiedCollectionMemberships.keyEnumerator nextObject];
        NSArray* itemKeys = [locallyModifiedCollectionMemberships objectForKey:collectionKey];

        ZPZoteroCollection* collection = [ZPZoteroCollection collectionWithKey:collectionKey];
        
        [ZPServerConnection removeItem:[itemKeys objectAtIndex:0] fromCollection:collection completion:^{
            
            [ZPDatabase removeItemKey:[itemKeys objectAtIndex:0] fromCollection:collectionKey];

            DDLogInfo(@"Removed 1 item from collection %@", collection.title);
            
            // Proceed with other uploads
            [self uploadMetadata];
        }];
        return TRUE;
    }
    else{
        return FALSE;
    }
}


@end
