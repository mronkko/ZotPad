//
//  ZPServerConnection.h
//  ZotPad
//
//  Handles communication with Zotero server.
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPAuthenticationDialog.h"
#import "ZPServerResponseXMLParser.h"




#import "ZPFileChannel.h"


@interface ZPServerConnection : NSObject{
}

// Check if the connection is already authenticated
+(BOOL) authenticated;

// Methods to get data from the server
+(void) retrieveLibrariesFromServer;
+(void) retrieveCollectionsForLibraryFromServer:(NSInteger)libraryID;

+(void) retrieveItemsFromLibrary:(NSInteger)libraryID itemKeys:(NSArray*)keys;

+(void) retrieveKeysInLibrary:(NSInteger)libraryID collection:(NSString*)key;
+(void) retrieveKeysInLibrary:(NSInteger)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString tags:(NSArray*)tags orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending;
    
+(void) retrieveTimestampForLibrary:(NSInteger)libraryID collection:(NSString*)key;
+(void) retrieveAllItemKeysFromLibrary:(NSInteger)libraryID;

//This retrieves single item details and notes and attachments associated with that item
+(void) retrieveSingleItemAndChildrenFromServer:(ZPZoteroItem*)item;

//This retrieves a single attachment and processes it with a block
+(void) retrieveSingleItem:(ZPZoteroAttachment*)item completion:(void(^)(NSArray*))completionBlock;

+(NSInteger) numberOfActiveMetadataRequests;

//Write API requests

+(void) createCollection:(ZPZoteroCollection*)collection completion:(void(^)(ZPZoteroCollection*))completionBlock;
+(void) addItems:(NSArray*)itemKeys toCollection:(ZPZoteroCollection*)collection completion:(void(^)(void))completionBlock;
+(void) removeItem:(NSString*)itemKey fromCollection:(ZPZoteroCollection*)collection completion:(void(^)(void))completionBlock;

+(void) editAttachment:(ZPZoteroAttachment*)attachment completion:(void(^)(ZPZoteroAttachment*))completionBlock conflict:(void(^)(void))conflictBlock;
+(void) editItem:(ZPZoteroItem*)item completion:(void(^)(ZPZoteroItem*))completionBlock conflict:(void(^)(void))conflictBlock;

+(void) createNote:(ZPZoteroNote*)note completion:(void(^)(ZPZoteroNote*))completionBlock;
+(void) editNote:(ZPZoteroNote*)note completion:(void(^)(ZPZoteroNote*))completionBlock conflict:(void(^)(void))conflictBlock;
+(void) deleteNote:(ZPZoteroNote*)note completion:(void(^)(void))completionBlock conflict:(void(^)(void))conflictBlock;

+(NSInteger) numberOfActiveMetadataWriteRequests;

@end
