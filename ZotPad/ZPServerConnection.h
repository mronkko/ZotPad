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
#import "ZPFileChannel.h"

@interface ZPServerConnection : NSObject <UIAlertViewDelegate>{
        
    NSInteger _activeRequestCount;
    NSMutableSet* _activeDownloads;
    NSMutableSet* _activeUploads;
    
    ZPFileChannel* _fileChannel_WebDAV;
    ZPFileChannel* _fileChannel_Dropbox;
    ZPFileChannel* _fileChannel_Zotero;
}

// This class is used as a singleton
+ (ZPServerConnection*) instance;

// Check if the connection is already authenticated
- (BOOL) authenticated;

- (BOOL) hasInternetConnection;

// Methods to get data from the server
-(NSArray*) retrieveLibrariesFromServer;
-(NSArray*) retrieveCollectionsForLibraryFromServer:(NSNumber*)libraryID;

-(NSArray*) retrieveItemsFromLibrary:(NSNumber*)libraryID itemKeys:(NSArray*)keys;

-(NSArray*) retrieveKeysInContainer:(NSNumber*)libraryID collectionKey:(NSString*)key;
-(NSArray*) retrieveKeysInContainer:(NSNumber*)libraryID collectionKey:(NSString*)collectionKey searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending;
    
-(NSString*) retrieveTimestampForContainer:(NSNumber*)libraryID collectionKey:(NSString*)key;
-(NSArray*) retrieveAllItemKeysFromLibrary:(NSNumber*)libraryID;

//This retrieves single item details and notes and attachments associated with that item
-(ZPZoteroItem*) retrieveSingleItemDetailsFromServer:(ZPZoteroItem*)item;

// Asynchronous downloading of files
-(NSInteger) numberOfFilesDownloading;
-(BOOL) checkIfCanBeDownloadedAndStartDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) finishedDownloadingAttachment:(ZPZoteroAttachment*)attachment toFileAtPath:(NSString*) tempFile withVersionIdentifier:(NSString*) identifier usingFileChannel:(ZPFileChannel*)fileChannel;
-(void) failedDownloadingAttachment:(ZPZoteroAttachment*)attachment withError:(NSError*) error usingFileChannel:(ZPFileChannel*)fileChannel;
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) useProgressView:(UIProgressView*) progressView forDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(BOOL) isAttachmentDownloading:(ZPZoteroAttachment*)attachment;

//Asynchronous uploading of files
-(NSInteger) numberOfFilesUploading;
-(void) uploadVersionOfAttachment:(ZPZoteroAttachment*)attachment;
-(void) finishedUploadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) failedUploadingAttachment:(ZPZoteroAttachment*)attachment withError:(NSError*) error usingFileChannel:(ZPFileChannel*)fileChannel;
-(void) canceledUploadingAttachment:(ZPZoteroAttachment*)attachment usingFileChannel:(ZPFileChannel*)fileChannel;
-(void) useProgressView:(UIProgressView*) progressView forUploadingAttachment:(ZPZoteroAttachment*)attachment;
-(BOOL) isAttachmentUploading:(ZPZoteroAttachment*)attachment;

@end
