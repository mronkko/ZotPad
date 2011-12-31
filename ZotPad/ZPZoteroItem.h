//
//  ZPZoteroItem.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//


#import <Foundation/Foundation.h>


@interface ZPZoteroItem : NSObject{
    NSString* _title;
    NSString* _key;
    NSString* _publishedIn;
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
    
}

@property (retain) NSString* title;
@property (retain) NSString* fullCitation;
@property (retain) NSString* creatorSummary;
@property (retain) NSString* publishedIn;
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

+(ZPZoteroItem*) ZPZoteroItemWithKey:(NSString*) key;
-(NSString*)key;

@end
