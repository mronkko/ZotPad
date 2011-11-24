//
//  ZPItemRetrieveOperation.h
//  ZotPad
//
//  This class retrieves items from the Zotero server. Items are retrieved in three passes
//  1) Top level items
//  2) Attachment items
//  3) Attachment files
//
//  The operation gets a reference to an array and parameters of the current view. (A view 
//  means the list of items that are currently shown). The operation will fill the array
//  with item IDs and then record data about these items in the database.
//
//  Each operation does one API call to the server and if needed, schedules more calls
//
//  Tutorial on NSOperation http://developer.apple.com/cocoa/managingconcurrency.html
//
//  Created by Rönkkö Mikko on 11/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPItemRetrieveOperation : NSOperation{
    NSArray* itemIDs;
    NSInteger libraryID;
    NSString* collectionKey;
    BOOL sortIsDescending;
    NSString* searchString;
    NSString* sortField;
}

@property (retain) NSArray* itemIDs;
@property NSInteger libraryID;
@property (retain) NSString* collectionKey;
@property BOOL sortIsDescending;
@property (retain) NSString* searchString;
@property (retain) NSString* sortField;

-(id) initWithArray:(NSArray*)itemArray library:(NSInteger)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString sortField:(NSString*)sortField sortDescending:(BOOL)sortIsDescending;

@end
