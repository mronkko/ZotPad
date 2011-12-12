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
    NSMutableArray* _itemIDs;
    NSInteger _libraryID;
    NSString* _collectionKey;
    BOOL _sortIsDescending;
    NSString* _searchString;
    NSString* _OrderField;
    BOOL _initial;
    NSOperationQueue* _queue;
    BOOL _notWithActiveView;
}

-(id) initWithArray:(NSMutableArray*)itemArray library:(NSInteger)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString OrderField:(NSString*)OrderField sortDescending:(BOOL)sortIsDescending queue:(NSOperationQueue*) queue;

-(void) markAsInitialRequestForCollection;

/*
 
 Calling this method tells the item retrieve operation that it is no longer workign for the active view
 
 */

-(void) markAsNotWithActiveView;

@end
