//
//  ZPServerConnection.h
//  ZotPad
//
//  Handles communication with Zotero server. Used as a singleton.
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPAuthenticationDialog.h"
#import "ZPServerResponseXMLParser.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroLibrary.h"

@interface ZPServerConnection : NSObject{
        
    // Dialog that will show the Zotero login
 
    BOOL _debugServerConnection;
    
    NSInteger _activeRequestCount;
}

// This class is used as a singleton
+ (ZPServerConnection*) instance;

// Check if the connection is already authenticated
- (BOOL) authenticated;

// Methods to get data from the server
-(NSArray*) retrieveLibrariesFromServer;
-(NSArray*) retrieveCollectionsForLibraryFromServer:(NSNumber*)libraryID;


-(ZPZoteroCollection*) retrieveCollection:(NSString*)collectionKey fromLibrary:(NSNumber*)libraryID;
//Retrieves the update timestamp and number of top level items
-(ZPZoteroLibrary*)retrieveLibrary:(NSNumber*) libraryID;

-(ZPServerResponseXMLParser*) retrieveItemsFromLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortIsDescending limit:(NSInteger)maxCount start:(NSInteger)offset;

-(ZPZoteroItem*) retrieveSingleItemDetailsFromServer:(ZPZoteroItem*)key;

@end
