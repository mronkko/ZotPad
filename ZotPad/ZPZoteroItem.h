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
    NSInteger _libraryID;
    NSString* _itemType;
    NSInteger _numChildren;
    NSInteger _numTags;
    
    BOOL _hasChildren;
}

@property (retain) NSString* title;
@property (retain) NSString* key;
@property (retain) NSString* creatorSummary;
@property (retain) NSString* publishedIn;
@property (assign) NSInteger year;
@property (assign) NSInteger libraryID;
@property (assign) BOOL hasChildren;
@property (retain) NSString* itemType;
@property (assign) NSInteger numChildren;
@property (assign) NSInteger numTags;


@end
