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
    NSString* _publicationTitle;
    NSString* _creatorSummary;
    NSNumber* _date;
    NSString* _itemType;
    NSNumber* _numTags;
    NSString* _fullCitation;
    
    NSArray* _creators;
    NSArray* _attachments;
    NSArray* _notes;
    NSDictionary* _fields;

    BOOL _isStandaloneAttachment;
    BOOL _isStandaloneNote;
    
    NSArray* _collections;
}

@property (retain) NSString* fullCitation;
@property (retain) NSString* creatorSummary;
@property (retain) NSString* publicationTitle;
@property (retain) NSNumber* date;
@property (retain) NSString* itemType;
@property (retain) NSNumber* numTags;
@property (retain) NSArray* notes;
@property (retain) NSArray* attachments;
@property (retain) NSArray* creators;
@property (retain) NSDictionary* fields;
@property (retain, readonly) NSString* itemKey;

+(void) dropCache;
-(NSArray*) collections;

@end
