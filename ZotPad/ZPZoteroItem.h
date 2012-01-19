//
//  ZPZoteroItem.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//


#import <Foundation/Foundation.h>

//ZPZoteroAttachment imports this file, so we cannot import it to avoid a circular dependency
//See this http://stackoverflow.com/questions/322597/class-vs-import/323510#323510
@class ZPZoteroAttachment;

@interface ZPZoteroItem : NSObject{
    NSString* _title;
    NSString* _key;
    NSString* _publicationTitle;
    NSString* _creatorSummary;
    NSInteger _year;
    NSNumber* _libraryID;
    NSString* _itemType;
    NSInteger _numChildren;
    NSInteger _numTags;
    NSString* _fullCitation;
    
    BOOL _hasChildren;
    NSArray* _creators;
    NSArray* _attachments;
    NSArray* _notes;
    NSDictionary* _fields;
    NSString* _lastTimestamp;

    BOOL _needsToBeWrittenToCache;
    BOOL _isStandaloneAttachment;
    BOOL _isStandaloneNote;
}

@property (retain) NSString* title;
@property (retain) NSString* fullCitation;
@property (retain) NSString* creatorSummary;
@property (retain) NSString* publicationTitle;
@property (assign) NSInteger year;
@property (retain) NSNumber* libraryID;
@property (assign) BOOL hasChildren;
@property (retain) NSString* itemType;
@property (assign) NSInteger numChildren;
@property (assign) NSInteger numTags;
@property (retain) NSString* lastTimestamp;

@property (retain) NSArray* notes;
@property (retain) NSArray* attachments;
@property (retain) NSArray* creators;
@property (retain) NSDictionary* fields;

+(BOOL) existsInCache:(NSString*) key;
+(ZPZoteroItem*) retrieveOrInitializeWithKey:(NSString*) key;
-(NSString*)key;
-(BOOL) needsToBeWrittenToCache;
-(void) clearNeedsToBeWrittenToCache;
//-(ZPZoteroAttachment*) firstExistingAttachment;
-(NSArray*) allExistingAttachments;

+(void) dropCache;


@end
