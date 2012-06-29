//
//  ZPZoteroItem.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "ZPZoteroDataObject.h"

@interface ZPZoteroItem : ZPZoteroDataObject{
    
    __strong NSArray* _creators;
    __strong NSArray* _attachments;
    __strong NSArray* _notes;
    __strong NSDictionary* _fields;

    BOOL _isStandaloneAttachment;
    BOOL _isStandaloneNote;
    
    NSArray* _collections;
}

@property (retain) NSString* dateAdded;
@property (retain) NSString* fullCitation;
@property (readonly) NSString* creatorSummary;
@property (readonly) NSString* publicationDetails;
@property (readonly) NSInteger year;
@property (readonly) NSString* itemType;
@property (retain) NSNumber* numTags;
@property (retain) NSArray* notes;
@property (retain) NSArray* attachments;
@property (retain) NSArray* creators;
@property (retain) NSDictionary* fields;
@property (retain, readonly) NSString* itemKey;

//Used for versioning by Zotero

@property (retain) NSString* etag;

// This is not stored in DB, but only used to temporarily store what the server returns us so that we can construct more robust updates.
@property (retain) NSString* jsonFromServer;

+(void) dropCache;
-(NSArray*) collections;

- (NSString*) shortCitation;

@end
