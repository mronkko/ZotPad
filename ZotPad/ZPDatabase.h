//
//  ZPDatabase.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>






#import "../FMDB/src/FMDatabase.h"
#import "../FMDB/src/FMResultSet.h"

@interface ZPDatabase : NSObject{
     

}


+(void) resetDatabase;

/*
 
 Methods for reading from DB
 
 */



// Methods for retrieving data from the data layer
+(NSArray*) libraries;
+(NSArray*) collectionsForLibrary : (NSInteger)currentlibraryID withParentCollection:(NSString*)currentCollectionKey;
+(NSArray*) collectionsForLibrary : (NSInteger)currentlibraryID;
+(NSString*) collectionKeyForFavoritesCollectionInLibrary: (NSInteger)libraryID;

// Methods for retrieving item keys
+(NSArray*) getItemKeysForLibrary:(NSInteger)libraryID collectionKey:(NSString*)collectionKey
                     searchString:(NSString*)searchString tags:(NSArray*)tags orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending;

+(NSArray*) getItemKeysForLibrary:(NSInteger)libraryID collectionKey:(NSString*)collectionKey;


//These are hard coded for now.
+(NSArray*) fieldsThatCanBeUsedForSorting;
+(NSString*) getFirstItemKeyWithTimestamp:(NSString*)timestamp from:(NSInteger)libraryID;
+(NSArray*) allAttachmentKeys;


// Methods for filling data into existing objects
+(void) addAttributesToGroupLibrary:(ZPZoteroLibrary*) library;
+(void) addAttributesToCollection:(ZPZoteroCollection*) collection;
+(NSDictionary*) attributesForItemWithKey:(NSString *)key;
+(NSDictionary*) attributesForAttachmentWithKey:(NSString *)key;
+(NSDictionary*) attributesForNoteWithKey:(NSString *)key;


+(void) addCreatorsToItem: (ZPZoteroItem*) item;
+(void) addFieldsToItem: (ZPZoteroItem*) item;
+(void) addNotesToItem: (ZPZoteroItem*) item;
+(void) addAttachmentsToItem: (ZPZoteroItem*) item;
+(void) addTagsToDataObject:(ZPZoteroDataObject*) dataObject;

//Return a list of all attachment paths ordered by priority for removel
+(NSArray*) getCachedAttachmentsOrderedByRemovalPriority;

//Return a list of all attachment paths priority for retrieval
+(NSArray*) getAttachmentsInLibrary:(NSInteger)libraryID collection:(NSString*)collectionKey;

+(NSString*) getLocalizationStringWithKey:(NSString*) key type:(NSString*) type locale:(NSString*) locale;

// Retrieves all item keys and note and attachment keys from the library

+(NSArray*) getAllItemKeysForLibrary:(NSInteger)libraryID;


+(NSArray*) collectionsForItem:(ZPZoteroItem*)item;
    
+(NSArray*) tagsForItemKeys:(NSArray*)itemKeys;
+(NSArray*) tagsForLibrary:(NSInteger)libraryID;

/*
 
 Methods for writing server data to DB

 */

// Methods for writing data to database
// These take an array of ZPZotero* objects instead of a single objects because batch editing or inserting results in a significant performance boost

+(void) writeLibraries:(NSArray*)libraries;
+(void) removeLibrariesNotInArray:(NSArray*)libraries;
+(void) writeCollections:(NSArray*)collections toLibrary:(ZPZoteroLibrary*)library;

// This method returns an array containing the items that were actually modified in the DB. This can be used to determine if fields and attachments
// need to be modified

+(NSArray*) writeItems:(NSArray*)items checkTimestamp:(BOOL) checkTimestamp;
+(NSArray*) writeNotes:(NSArray*)notesitems checkTimestamp:(BOOL) checkTimestamp;
+(NSArray*) writeAttachments:(NSArray*)attachmentsitems checkTimestamp:(BOOL) checkTimestamp;

+(void) writeVersionInfoForAttachment:(ZPZoteroAttachment*)attachment;

+(void) writeItems:(NSArray*)items toCollection:(NSString*)collectionKey;
+(void) addItemKeys:(NSArray*)keys toCollection:(NSString*)collectionKey;


+(void) writeItemsCreators:(NSArray*)items;
+(void) writeItemsFields:(NSArray*)items;
+(void) writeDataObjectsTags:(NSArray*)dataObjects;


// These remove items from the cache
+(void) removeItemKeysNotInArray:(NSArray*)itemKeys fromCollection:(NSString*)collectionKey;
+(void) removeItemKey:(NSString*)itemKey fromCollection:(NSString*)collectionKey;
+(void) deleteItemKeysNotInArray:(NSArray*)itemKeys fromLibrary:(NSInteger)libraryID;
+(void) deleteNote:(ZPZoteroNote*) note;

+(void) updateViewedTimestamp:(ZPZoteroAttachment*)attachment;
+(void) setUpdatedTimestampForCollection:(NSString*)collectionKey toValue:(NSString*)updatedTimestamp;
+(void) setUpdatedTimestampForLibrary:(NSInteger)libraryID toValue:(NSString*)updatedTimestamp;


/*

 Methods for writing locally edited data to DB
 
 */

+(void) addCollectionWithTitle:(NSString*) title collectionKey:(NSString*) collectionKey toLibrary:(ZPZoteroLibrary*)library;
+(void) replaceLocallyAddedCollection:(ZPZoteroCollection*) localCollection withServerVersion:(ZPZoteroCollection*) serverCollection;

// Locally modified collection memberships
+(void) addItemWithKeyLocally:(NSString*)itemKey toCollection:(NSString*)collectionKey;
+(void) removeItemWithKeyLocally:(NSString*)itemKey fromCollection:(NSString*)collectionKey;

// Locally modifying notes

+(void) createNoteLocally:(ZPZoteroNote*) note;
+(void) replaceLocallyAddedNote:(ZPZoteroNote*) localNote withServerVersion:(ZPZoteroNote*) serverNote;
+(void) deleteNoteLocally:(ZPZoteroNote*) note;
+(void) saveLocallyEditedNote:(ZPZoteroNote*) note;

+(void) saveLocallyEditedAttachmentNote:(ZPZoteroAttachment*) attachment;

// Locally modifying tags

// Methods for retrieving locally modified objects
+(NSArray*) locallyAddedCollections;

// Returns an array of attachments whose metadata has been edited locally
+(NSArray*) locallyEditedAttachments;

+(NSArray*) locallyEditedNotes;
+(NSArray*) locallyAddedNotes;
+(NSArray*) locallyDeletedNotes;

+(void) addTagsLocally:(NSArray*)tags toItemWithKey:(NSString*)key;
+(void) removeTagsLocally:(NSArray*)tags toItemWithKey:(NSString*)key;

+(NSArray*) attachmentsWithLocallyEditedTags;
+(NSArray*) itemsWithLocallyEditedTags;
+(NSArray*) notesWithLocallyEditedTags;

+(void) clearLocalEditFlagsForTagsWithItemKey:(NSString*)itemKey;

// Return a dictionary where the keys are collection keys and the objects are arrays of item keys

+(NSDictionary*) locallyAddedCollectionMemberships;
+(NSDictionary*) locallyDeletedCollectionMemberships;

// Troubleshooting
+(NSString*) base64encodedDBfile;

@end
