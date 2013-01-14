//
//  ZPCore.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 14.5.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

//Data objects

#import "ZPZoteroLibrary.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroAttachment.h"
#import "ZPZoteroNote.h"
#import "ZPZoteroDataOBject.h"

//Core classes for data and server connection

#import "ZPPreferences.h"
#import "ZPDatabase.h"

// Logger

#import "DDLog.h"

static const int ddLogLevel = LOG_LEVEL_OFF;

// Notifications about data available from server

static NSString *const ZPNOTIFICATION_ITEMS_AVAILABLE = @"ItemsAvailable";
static NSString *const ZPNOTIFICATION_ITEM_LIST_AVAILABLE = @"ItemListAvailable";
static NSString *const ZPNOTIFICATION_LIBRARY_WITH_COLLECTIONS_AVAILABLE  = @"LibraryAndCollectionsAvailable";

// Notifications about attachment file uploads, downloads and deletions

static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_DELETED = @"AttachmentFileDeleted";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_STARTED = @"AttachmentFileDownloadStarted";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FAILED = @"AttachmentFileDownloadFailed";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FINISHED = @"AttachmentFileDownloadFinished";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_STARTED = @"AttachmentFileUploadStarted";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_FAILED = @"AttachmentFileUploadFailed";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_FINISHED = @"AttachmentFileUploadFinished";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_QUEUED = @"AttachmentFileUploadQueued";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_CANCELED = @"AttachmentFileUploadCanceled";

// Notificaitions about errors

static NSString *const ZPNOTIFICATION_SERVER_CONNECTION_FAILED= @"ServerConnectionFailed";

// Notifications about authentication

static NSString *const ZPNOTIFICATION_ZOTERO_AUTHENTICATION_SUCCESSFUL = @"ZoteroAuthenticationSuccesful";
static NSString *const ZPNOTIFICATION_ZOTERO_AUTHENTICATION_FAILED = @"ZoteroAuthenticationFailed";

// Notifications about changes in what the user is viewing

static NSString *const ZPNOTIFICATION_ACTIVE_LIBRARY_CHANGED = @"ActiveLibraryChanged";
static NSString *const ZPNOTIFICATION_ACTIVE_COLLECTION_CHANGED = @"ActiveCollectionChanged";
static NSString *const ZPNOTIFICATION_ACTIVE_ITEM_CHANGED = @"ActiveItemChanged";
static NSString *const ZPNOTIFICATION_USER_INTERFACE_AVAILABLE = @"UserInterfaceAvailable";

//Dictionary keys for data objects and item list retrievals
//TODO: Check the entire project and makes sure that all dictionaries use these static keys

static NSString *const ZPKEY_LIBRARY_ID = @"libraryID";
static NSString *const ZPKEY_COLLECTION_KEY = @"collectionKey";

static NSString *const ZPKEY_ERROR = @"error";
static NSString *const ZPKEY_ITEM_KEY = @"itemKey";
static NSString *const ZPKEY_ITEM_KEY_ARRAY = @"itemKeys";
static NSString *const ZPKEY_ITEM = @"item";
static NSString *const ZPKEY_ATTACHMENT = @"attachment";

static NSString *const ZPKEY_TAG = @"tag";
static NSString *const ZPKEY_SEARCH_STRING = @"q";
static NSString *const ZPKEY_SORT_COLUMN = @"order";
static NSString *const ZPKEY_ORDER_DIRECTION = @"sort";

static NSString *const ZPKEY_ALL_RESULTS = @"allResults";
static NSString *const ZPKEY_PARAMETERS = @"params";

