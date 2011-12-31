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
#import "ZPZoteroAttachment.h"


@interface ZPServerConnection : NSObject{
        
    BOOL _debugServerConnection;
    NSInteger _activeRequestCount;
    
    NSMutableDictionary* _attachmentFileDataObjectsByConnection;
    NSMutableDictionary* _attachmentObjectsByConnection;
}

// This class is used as a singleton
+ (ZPServerConnection*) instance;

// Check if the connection is already authenticated
- (BOOL) authenticated;

// Methods to get data from the server
-(NSArray*) retrieveLibrariesFromServer;
-(NSArray*) retrieveCollectionsForLibraryFromServer:(NSNumber*)libraryID;

-(ZPServerResponseXMLParser*) retrieveItemsFromLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortIsDescending limit:(NSInteger)maxCount start:(NSInteger)offset getItemDetails:(BOOL)getItemDetails;

-(ZPServerResponseXMLParser*) retrieveNotesAndAttachmentsFromLibrary:(NSNumber*)libraryID limit:(NSInteger)maxCount start:(NSInteger)offset;

-(ZPZoteroItem*) retrieveSingleItemDetailsFromServer:(ZPZoteroItem*)key;
-(void) downloadAttachment:(ZPZoteroAttachment*)attachment;

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;

@end
