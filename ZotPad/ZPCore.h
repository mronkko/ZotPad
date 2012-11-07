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

//Core classes for data and server connection

#import "ZPPreferences.h"
#import "ZPDatabase.h"
#import "ZPServerConnectionManager.h"

// Logger

#import "DDLog.h"

static const int ddLogLevel = LOG_LEVEL_INFO;

//Notifications

static NSString *const ZPNOTIFICATION_ITEMS_AVAILABLE = @"ItemsAvailable";
static NSString *const ZPNOTIFICATION_ITEM_LIST_AVAILABLE = @"ItemListAvailable";
static NSString *const ZPNOTIFICATION_LIBRARY_WITH_COLLECTIONS_AVAILABLE  = @"LibraryAndCollectionsAvailable";

static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_DELETED = @"AttachmentFileDeleted";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_STARTED = @"AttachmentFileDownloadStarted";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FAILED = @"AttachmentFileDownloadFailed";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FINISHED = @"AttachmentFileDownloadFinished";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_STARTED = @"AttachmentFileUploadStarted";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_FAILED = @"AttachmentFileUploadFailed";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_FINISHED = @"AttachmentFileUploadFinished";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_QUEUED = @"AttachmentFileUploadQueued";
static NSString *const ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_CANCELED = @"AttachmentFileUploadCanceled";

//Dictionary keys for data objects and item list retrievals

static NSString *const ZPKEY_LIBRARY_ID = @"libraryID";
static NSString *const ZPKEY_COLLECTION_KEY = @"collectionKey";

static NSString *const ZPKEY_ERROR = @"error";
static NSString *const ZPKEY_ITEM_KEY = @"itemKey";
static NSString *const ZPKEY_ITEM_KEY_ARRAY = @"itemKeys";
static NSString *const ZPKEY_ITEM = @"item";
static NSString *const ZPKEY_ATTACHMENT = @"attachment";

static NSString *const ZPKEY_TAG = @"tag";
static NSString *const ZPKEY_SEARCH_STRING = @"searchString";
static NSString *const ZPKEY_SORT_COLUMN = @"order";
static NSString *const ZPKEY_ORDER_DIRECTION = @"sort";

static NSString *const ZPKEY_ALL_RESULTS = @"allResults";
static NSString *const ZPKEY_PARAMETERS = @"params";

