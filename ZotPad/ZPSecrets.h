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

static const NSString* DROPBOX_KEY = @"or7xa2bxhzit1ws";
static const NSString* DROPBOX_SECRET = @"6azju842azhs5oz";

static const NSString* DROPBOX_KEY_FULL_ACCESS = @"w1nps3e4js2va7z";
static const NSString* DROPBOX_SECRET_FULL_ACCESS = @"vvk17pjqx0ngjs3";

static const NSString* USERVOICE_API_KEY = @"7Dxx3D5IB1fvrc3X42KBTg";
static const NSString* USERVOICE_SECRET = @"hfThpmD59PwAtNf1aT9aK5RjrUZnvqg15aENZQxav8";

static const NSString* TESTFLIGHT_KEY = @"5e753f234f33fc2bddf4437600037fbf_NjcyMjEyMDEyLTA0LTA5IDE0OjUyOjU0LjE4MDQwMg";

static const NSString* CRITTERCISM_KEY = @"50e6e44a89ea7410f4000023";

#else

//  Production keys

static const NSString* ZOTERO_KEY = nil;
static const NSString* ZOTERO_SECRET = nil;

static const NSString* DROPBOX_KEY = nil;
static const NSString* DROPBOX_SECRET = nil;

static const NSString* DROPBOX_KEY_FULL_ACCESS = nil;
static const NSString* DROPBOX_SECRET_FULL_ACCESS = nil;

static const NSString* TESTFLIGHT_KEY = nil;

static const NSString* CRITTERCISM_KEY = @"50e6e3f6f716964fbb000021";

#endif




