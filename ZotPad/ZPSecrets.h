//
//  ZPSecrets.h
//  ZotPad
//
//  This file contains the secrets and keys that ZotPad uses to authenticate
//  with third party web services. The public GitHub repository contains the
//  Zotero secret and key used in the ZotPad beta app. If you want to
//  compile a production version of the app, you need to obtain a separate key.
//  (Or you can copy the beta key as the production key)
//
//  TestFlight and UserVoice keys are not included in the public repository.
//
//  Created by Mikko Rönkkö on 7/15/12.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//


#ifdef BETA

//  Beta keys

static const NSString* ZOTERO_KEY = @"26c0dd3450d3d7634f62";
static const NSString* ZOTERO_SECRET = @"d9077a7cb2f5f29bcbf0";

static const NSString* DROPBOX_KEY = nil;
static const NSString* DROPBOX_SECRET = nil;

static const NSString* DROPBOX_KEY_FULL_ACCESS = nil;
static const NSString* DROPBOX_SECRET_FULL_ACCESS = nil;

static const NSString* USERVOICE_API_KEY = nil;
static const NSString* USERVOICE_SECRET = nil;

static const NSString* TESTFLIGHT_KEY = nil;

static const NSString* CRITTERCISM_KEY = nil;

#else

//  Production keys

static const NSString* ZOTERO_KEY = nil;
static const NSString* ZOTERO_SECRET = nil;

static const NSString* DROPBOX_KEY = nil;
static const NSString* DROPBOX_SECRET = nil;

static const NSString* DROPBOX_KEY_FULL_ACCESS = nil;
static const NSString* DROPBOX_SECRET_FULL_ACCESS = nil;

static const NSString* TESTFLIGHT_KEY = nil;

static const NSString* CRITTERCISM_KEY = nil;

#endif




