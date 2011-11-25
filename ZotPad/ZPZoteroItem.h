//
//  ZPZoteroItem.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//


#import <Foundation/Foundation.h>


@interface ZPZoteroItem : NSObject{
    NSString* title;
    NSString* key;
    NSString* pubishedIn;
    NSString* authors;
    NSInteger year;
    NSInteger libraryID;
    NSString* itemType;
    NSString* creatorSummary;
    NSInteger numChildren;
    NSInteger numTags;
    
    BOOL hasChildren;
}

@property (retain) NSString* title;
@property (retain) NSString* key;
@property (retain) NSString* authors;
@property (retain) NSString* publishedIn;
@property (assign) NSInteger year;
@property (assign) NSInteger libraryID;
@property (assign) BOOL hasChildren;
@property (retain) NSString* itemType;
@property (retain) NSString* creatorSummary;
@property (assign) NSInteger numChildren;
@property (assign) NSInteger numTags;


@end
