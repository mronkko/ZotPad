
//
//  ZPFileChannel_WebDAV.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//


#import "ZPCore.h"

#import "ZPFileChannel_WebDAV.h"
#import "ZPPreferences.h"
#import "ZPServerConnection.h"
#import "ASIHTTPRequest.h"

#import "ZPDatabase.h"

#import "SBJson.h"


//Unzipping and base64 decoding
#import "ZipArchive.h"


NSInteger const ZPFILECHANNEL_WEBDAV_DOWNLOAD = 1;
NSInteger const ZPFILECHANNEL_WEBDAV_UPLOAD_FILE = 2;
NSInteger const ZPFILECHANNEL_WEBDAV_UPLOAD_UPDATE_LASTSYNC = 3;
NSInteger const ZPFILECHANNEL_WEBDAV_UPLOAD_REGISTER = 4;

// This is needed bacause WebDAV requests contain actually two request. The first request will just request the size of the file.

@interface ZPFileChannel_WebDAV_ProgressDelegate : NSObject <ASIHTTPRequestDelegate>{
    long long length;
    long long received;
}
-(id) initWithUIProgressView:(UIProgressView*)view;

@property (retain) UIProgressView* progressView;

@end

@implementation ZPFileChannel_WebDAV_ProgressDelegate

@synthesize progressView;

-(id) initWithUIProgressView:(UIProgressView*)view{
    self = [super init];
    progressView = view;
    length = 0;
    received = 0;
    return self;
}

-(int) fileChannelType{
    return VERSION_SOURCE_WEBDAV;
}

- (void)request:(ASIHTTPRequest *)request didReceiveBytes:(long long)bytes{
    received += bytes;

    //Only update the progress view when the file has started downloading.
    
    if([request responseStatusCode] == 200){
        float progress = (float)received/length;
        [self.progressView setProgress:progress];
    }
}
- (void)request:(ASIHTTPRequest *)request incrementDownloadSizeBy:(long long)newLength{
    length += newLength;
}

@end

@interface ZPFileChannel_WebDAV()

-(void) _performWebDAVUpload:(ZPZoteroAttachment*)attachment;
-(void) _updateLastSync:(ZPZoteroAttachment*)attachment;
-(void) _registerWebDAVUploadWithZoteroServer:(ZPZoteroAttachment*)attachment;

@end
    
@implementation ZPFileChannel_WebDAV


- (id) init{
    self= [super init];
    downloadProgressDelegates = [[NSMutableDictionary alloc] init];
    return self;
}

#pragma mark - Downloading

-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    //Setup the request 
    NSString* WebDAVRoot = [[ZPPreferences instance] webDAVURL];
    NSString* key =  attachment.key;
    NSString* urlString = [WebDAVRoot stringByAppendingFormat:@"/%@.zip",key];
    NSURL *url = [NSURL URLWithString:urlString]; 
    
    DDLogInfo(@"Downloading file %@ from WebDAV url %@",attachment.filename, urlString);
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url]; 
    
    [self linkAttachment:attachment withRequest:request];
        
    NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
    [request setDownloadDestinationPath:tempFile];
    
    //For some reason authentication using digest fails if persistent connections are in use
    [request setShouldAttemptPersistentConnection:NO];
    [request setShouldPresentAuthenticationDialog:YES];
    [request setUseKeychainPersistence:YES];
    [request setRequestMethod:@"GET"];
    [request setDelegate:self];
    [request setShowAccurateProgress:TRUE];

    request.userInfo = [NSDictionary dictionaryWithObject:attachment forKey:@"attachment"];
    request.tag = ZPFILECHANNEL_WEBDAV_DOWNLOAD;
    
    [request startAsynchronous];

}
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    
    if(request != NULL){
        [request cancel];
        [self cleanupAfterFinishingAttachment:attachment];
    }
}
-(void) useProgressView:(UIProgressView*) progressView forDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    
    if(request != NULL){
        ZPFileChannel_WebDAV_ProgressDelegate* progressDelegate;
        @synchronized(downloadProgressDelegates){
            progressDelegate = [downloadProgressDelegates objectForKey:[NSNumber numberWithInt: attachment]];
            
            if(progressDelegate == NULL){
                progressDelegate  = [[ZPFileChannel_WebDAV_ProgressDelegate alloc] initWithUIProgressView:progressView];
                [downloadProgressDelegates setObject:progressDelegate forKey:[NSNumber numberWithInt: attachment]];
            }
            else{
                progressDelegate.progressView = progressView;
            }
        }
        [request setDownloadProgressDelegate:progressDelegate];
    }
}

#pragma mark - Uploading


-(void) startUploadingAttachment:(ZPZoteroAttachment*)attachment{
    
    //Download new attachment metadata
    
    //TODO: Refactor this to call ZPCacheController instead so that the response from the server is stored in the DB. 

    attachment = [[[ZPServerConnection instance] retrieveItemsFromLibrary:attachment.libraryID itemKeys:[NSArray arrayWithObject:attachment.key]] objectAtIndex:0];
    DDLogVerbose(@"Reveived MD5 from server %@",attachment.md5);
    
    if(! [attachment.md5 isEqualToString:attachment.versionIdentifier_local]){
        //Conflict
        DDLogWarn(@"Local MD5 %@ conflicts with server MD5 %@",attachment.versionIdentifier_local,attachment.md5);
        if(attachment.fileExists_original){
            DDLogWarn(@"Original file MD5: %@",[ZPZoteroAttachment md5ForFileAtPath:attachment.fileSystemPath_original]);
        }
        else {
            DDLogCWarn(@"Original file does not exists in cache");
        }
        DDLogWarn(@"Modified file MD5: %@",[ZPZoteroAttachment md5ForFileAtPath:attachment.fileSystemPath_modified]);
        
        //If the version that we have downloaded from the server is different than what exists on the server now, delete the local copy
        if(! [attachment.md5 isEqualToString:attachment.versionIdentifier_server]){

            DDLogWarn(@"Removing cached copy of file %@ because the local (%@) and server (%@) version identifiers differ.",attachment.filename,attachment.versionIdentifier_server,attachment.md5);
            
            [attachment purge_original:@"File is outdated (WebDAV pre-check)"];
            
            attachment.versionIdentifier_server = attachment.md5;
            [[ZPDatabase instance] writeVersionInfoForAttachment:attachment];
        }
        [self presentConflictViewForAttachment:attachment];

    }
    else{
        [self _performWebDAVUpload:attachment];
    }
}

-(void) _registerWebDAVUploadWithZoteroServer:(ZPZoteroAttachment*)attachment{
    
    //Start uploading item metadata
    
    NSString* path = attachment.fileSystemPath_modified;
    NSDictionary* documentFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES];
    NSTimeInterval timeModified = [[documentFileAttributes fileModificationDate] timeIntervalSince1970];
    long long timeModifiedMilliseconds = (long long) trunc(timeModified * 1000.0f);
    attachment.versionIdentifier_local = [ZPZoteroAttachment md5ForFileAtPath:path];    
    
    if(attachment.versionIdentifier_local==NULL){
        [NSException raise:@"MD5 cannot be null" format:@""];
    }
    NSString* oauthkey =  [[ZPPreferences instance] OAuthKey];
    NSString* urlString = [NSString stringWithFormat:@"https://api.zotero.org/users/%@/items/%@?key=%@",[[ZPPreferences instance] userID],attachment.key, oauthkey];
    
    ASIHTTPRequest* request = [[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    
    request.userInfo = [NSDictionary dictionaryWithObject:attachment forKey:@"attachment"];
    request.tag = ZPFILECHANNEL_WEBDAV_UPLOAD_REGISTER;
    request.delegate = self;
    
    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request addRequestHeader:@"If-Match" value:attachment.etag];
    
    //Update the JSON
    NSDictionary* oldJsonContent = (NSDictionary*) [attachment.jsonFromServer JSONValue];
    NSMutableDictionary* jsonContent = [NSMutableDictionary dictionaryWithDictionary:oldJsonContent];
    
    [jsonContent setObject:attachment.versionIdentifier_local forKey:@"md5"];
    [jsonContent setObject:[NSNumber numberWithLongLong:timeModifiedMilliseconds] forKey:@"mtime"];
    
    
    NSString* jsonString = [jsonContent JSONRepresentation];
    [request appendPostData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]];
    request.requestMethod = @"PUT";
    
    DDLogInfo(@"Uploading metadata about new version (%@) of file %@ to Zotero ",attachment.versionIdentifier_local,attachment.filename);
    
    [request startAsynchronous];
}

-(void) _performWebDAVUpload:(ZPZoteroAttachment*)attachment{
    //Setup the request 
    NSString* WebDAVRoot = [[ZPPreferences instance] webDAVURL];
    NSString* key =  attachment.key;
    NSString* urlString = [WebDAVRoot stringByAppendingFormat:@"/%@.zip",key];
    NSURL *url = [NSURL URLWithString:urlString]; 
    
    DDLogVerbose(@"Uploading file %@ to WebDAV %@",urlString,attachment.filename);
    
    ASIHTTPRequest *uploadRequest = [ASIHTTPRequest requestWithURL:url]; 
    
    [self linkAttachment:attachment withRequest:uploadRequest];
    
    //For some reason authentication using digest fails if persistent connections are in use
    [uploadRequest setShouldAttemptPersistentConnection:NO];
    [uploadRequest setShouldPresentAuthenticationDialog:YES];
    [uploadRequest setUseKeychainPersistence:YES];
    
    //Zip the file before uploading
    
    ZipArchive* zipArchive = [[ZipArchive alloc] init];
    
    NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
        
    [zipArchive CreateZipFile2:tempFile];
    [zipArchive addFileToZip:attachment.fileSystemPath_modified newname:attachment.filenameZoteroBase64Encoded];
    [zipArchive CloseZipFile2];
    
    [uploadRequest appendPostDataFromFile:tempFile];
    
    [[NSFileManager defaultManager] removeItemAtPath:tempFile error:NULL];
    [uploadRequest setRequestMethod:@"PUT"];
    [uploadRequest setDelegate:self];
    
    uploadRequest.userInfo = [NSDictionary dictionaryWithObject:attachment forKey:@"attachment"];
    uploadRequest.tag = ZPFILECHANNEL_WEBDAV_UPLOAD_FILE;
        
    [uploadRequest startAsynchronous];

    
}

-(void) _updateLastSync:(ZPZoteroAttachment *)attachment{

    //Setup the request 
    NSString* WebDAVRoot = [[ZPPreferences instance] webDAVURL];
    NSString* urlString = [WebDAVRoot stringByAppendingString:@"/lastsync"];
    NSURL *url = [NSURL URLWithString:urlString]; 
    
    ASIHTTPRequest *uploadRequest = [ASIHTTPRequest requestWithURL:url]; 
    
    [self linkAttachment:attachment withRequest:uploadRequest];
    
    //For some reason authentication using digest fails if persistent connections are in use
    [uploadRequest setShouldAttemptPersistentConnection:NO];
    [uploadRequest setShouldPresentAuthenticationDialog:YES];
    [uploadRequest setUseKeychainPersistence:YES];
        
    [uploadRequest appendPostData:[@"1" dataUsingEncoding:NSUTF8StringEncoding]];
    
    [uploadRequest setRequestMethod:@"PUT"];
    [uploadRequest setDelegate:self];
    
    uploadRequest.userInfo = [NSDictionary dictionaryWithObject:attachment forKey:@"attachment"];
    uploadRequest.tag = ZPFILECHANNEL_WEBDAV_UPLOAD_UPDATE_LASTSYNC;
    
    [uploadRequest startAsynchronous];
    
    
}
-(void) useProgressView:(UIProgressView*) progressView forUploadingAttachment:(ZPZoteroAttachment*)attachment{
    
    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    
    if(request != NULL){
        if(request.tag == ZPFILECHANNEL_WEBDAV_UPLOAD_FILE){
            [request setUploadProgressDelegate:progressView];
        }
    }
}


#pragma mark - Callbacks

- (void)requestFinished:(ASIHTTPRequest *)request{
    
    ZPZoteroAttachment* attachment = [request.userInfo objectForKey:@"attachment"];
    
    if(request.tag == ZPFILECHANNEL_WEBDAV_DOWNLOAD){

        if(request.responseStatusCode == 200){
            if([attachment.linkMode intValue] == LINK_MODE_IMPORTED_URL && [attachment.contentType isEqualToString:@"text/html"]){
                NSString* tempFile = [request downloadDestinationPath];
                NSString* md5 = [ZPZoteroAttachment md5ForFileAtPath:tempFile];
                DDLogVerbose(@"The MD5 sum of the file received from server is %@", md5);
                [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:tempFile withVersionIdentifier:md5 usingFileChannel:self];
            }
            
            else {
                //Unzip the attachment
                ZipArchive* zipArchive = [[ZipArchive alloc] init];
                [zipArchive UnzipOpenFile:[request downloadDestinationPath]];
                
                NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
                
                [zipArchive UnzipFileTo:tempFile overWrite:YES];
                [zipArchive UnzipCloseFile];
                
                //Check that the file that we wanted exits
                NSString* encodedFileName = attachment.filenameZoteroBase64Encoded;
                tempFile = [tempFile stringByAppendingPathComponent:encodedFileName];
                
                if(![[NSFileManager defaultManager] fileExistsAtPath:tempFile]){
                    NSString* errorMessage = [NSString stringWithFormat:@"Zip file downloaded from WebDAV URL %@ did not contain file %@ (%@)",[request.url absoluteString], attachment.filenameZoteroBase64Encoded,attachment.filename];

                    DDLogError(errorMessage);

                    NSError* error = [[NSError alloc] initWithDomain:[request.url host] code:request.responseStatusCode userInfo:[NSDictionary dictionaryWithObject:errorMessage forKey:NSLocalizedDescriptionKey]];
                    [[ZPServerConnection instance] failedDownloadingAttachment:attachment withError:error usingFileChannel:self];
                }
                else{
                    NSString* md5 = [ZPZoteroAttachment md5ForFileAtPath:tempFile];
                    DDLogVerbose(@"The MD5 sum of the file received from server is %@", md5);
                    [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:tempFile withVersionIdentifier:md5 usingFileChannel:self];
                }
            }
        }
        
        else{
            NSError* error = [[NSError alloc] initWithDomain:[request.url host] code:request.responseStatusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"WebDAV request to %@ returned %@",request.url,request.responseStatusMessage] forKey:NSLocalizedDescriptionKey]];
            [[ZPServerConnection instance] failedDownloadingAttachment:attachment withError:error usingFileChannel:self];
        }        
        

        
        [self cleanupAfterFinishingAttachment:attachment];
    }
    
    // Uploads 
    
    else {
        
        
        
        if(request.tag == ZPFILECHANNEL_WEBDAV_UPLOAD_FILE && (request.responseStatusCode == 204 || request.responseStatusCode == 201)){
            [self _updateLastSync:attachment];   
        }
        
        else if(request.tag == ZPFILECHANNEL_WEBDAV_UPLOAD_UPDATE_LASTSYNC &&  (request.responseStatusCode == 204 || request.responseStatusCode == 201)){
            [self _registerWebDAVUploadWithZoteroServer:attachment];   
        }
        
        else if(request.tag == ZPFILECHANNEL_WEBDAV_UPLOAD_REGISTER && request.responseStatusCode == 200){
            
            //DDLogVerbose([self requestDumpAsString:request]);
            //All done
            [[ZPServerConnection instance] finishedUploadingAttachment:attachment];
            [self cleanupAfterFinishingAttachment:attachment];
            
        }
        else if(request.tag == ZPFILECHANNEL_WEBDAV_UPLOAD_REGISTER && request.responseStatusCode == 412){
            //Conflict. 
            
            //Download new attachment metadata
            
            //TODO: Refactor this to call ZPCacheController instead so that the response from the server is stored in the DB. 
            
            attachment = [[[ZPServerConnection instance] retrieveItemsFromLibrary:attachment.libraryID itemKeys:[NSArray arrayWithObject:attachment.key]] objectAtIndex:0];
            
            //If the version that we have downloaded from the server is different than what exists on the server now, delete the local copy
            if(! [attachment.md5 isEqualToString:attachment.versionIdentifier_server]){
                [attachment purge_original:@"File is outdated (WebDAV conflict)"];
                attachment.versionIdentifier_server = attachment.md5;
                [[ZPDatabase instance] writeVersionInfoForAttachment:attachment];
            }
            [self presentConflictViewForAttachment:attachment];
        }
        else{
            NSError* error =[NSError errorWithDomain:request.url.host code:request.responseStatusCode userInfo:[NSDictionary dictionaryWithObject:request.responseStatusMessage forKey:NSLocalizedDescriptionKey]];
            [self cleanupAfterFinishingAttachment:attachment];
            [[ZPServerConnection instance] failedUploadingAttachment:attachment withError:error usingFileChannel:self];
        }
    }
}

- (void)requestFailed:(ASIHTTPRequest *)request{
    NSError *error = [request error];

    ZPZoteroAttachment* attachment = [request.userInfo objectForKey:@"attachment"];

    DDLogError(@"Request to %@ failed: %@", request.url, [error description]);

    //If there was an authentication issue, reauthenticate
    if(error.code == 3){
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Authentication failed"
                                                          message:@"Authenticating with WebDAV server failed."
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                                otherButtonTitles:@"Disable WebDAV",nil];
        
        [message show];
    }
    if(error.code == 5){
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Configuration error"
                                                          message:@"WebDAV addresss is not configured properly. Please check ZotPad settings."
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                                otherButtonTitles:@"Disable WebDAV",nil];
        
        [message show];
    }
    
    if(request.tag == ZPFILECHANNEL_WEBDAV_DOWNLOAD){
        [[ZPServerConnection instance] failedDownloadingAttachment:attachment withError:error usingFileChannel:self];
    }
    else{
        [[ZPServerConnection instance] failedUploadingAttachment:attachment withError:error usingFileChannel:self];
    }
    
    [self cleanupAfterFinishingAttachment:attachment];
}

-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment *)attachment{
    @synchronized(downloadProgressDelegates){
        [downloadProgressDelegates removeObjectForKey:[NSNumber numberWithInt: attachment]];
    }

}
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    //Disable webdav
    if(buttonIndex == 1){
        [[ZPPreferences instance] setUseWebDAV:FALSE];
    }
}


@end
