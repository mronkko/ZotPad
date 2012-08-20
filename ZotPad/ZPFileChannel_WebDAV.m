
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
NSInteger const ZPFILECHANNEL_WEBDAV_UPLOAD_UPDATE_PROP = 4;
NSInteger const ZPFILECHANNEL_WEBDAV_UPLOAD_REGISTER = 5;

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

-(void) _registerWebDAVUploadWithZoteroServer:(ZPZoteroAttachment*)attachment userInfo:(NSDictionary*) userInfo;
-(void) _performWebDAVUploadForAttachment:(ZPZoteroAttachment*)attachment tag:(NSInteger)tag userInfo:(NSDictionary*) userInfo;

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
    NSString* WebDAVRoot = [ZPPreferences webDAVURL];
    NSString* key =  attachment.key;
    NSString* urlString = [WebDAVRoot stringByAppendingFormat:@"/%@.zip",key];
    NSURL *url = [NSURL URLWithString:urlString]; 
    
    DDLogInfo(@"Downloading file %@ from WebDAV url %@",attachment.filename, urlString);
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url]; 
    
    [self linkAttachment:attachment withRequest:request];
        
    NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%f",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
    [request setDownloadDestinationPath:tempFile];
    
    //For some reason authentication using digest fails if persistent connections are in use
    [request setShouldAttemptPersistentConnection:NO];
    [request setShouldPresentAuthenticationDialog:YES];
    [request setUseKeychainPersistence:YES];
    [request setRequestMethod:@"GET"];
    [request setDelegate:self];
    [request setShowAccurateProgress:TRUE];
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* hostException = [defaults objectForKey:@"webdavsecurityexception"];
    if([[url host] isEqual:hostException]){
        [request setValidatesSecureCertificate:NO];
    }

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
            progressDelegate = [downloadProgressDelegates objectForKey:attachment.key];
            
            if(progressDelegate == NULL){
                progressDelegate  = [[ZPFileChannel_WebDAV_ProgressDelegate alloc] initWithUIProgressView:progressView];
                [downloadProgressDelegates setObject:progressDelegate forKey:attachment.key];
            }
            else{
                progressDelegate.progressView = progressView;
            }
        }
        [request setDownloadProgressDelegate:progressDelegate];
    }
}

#pragma mark - Uploading


-(void) startUploadingAttachment:(ZPZoteroAttachment*)attachment overWriteConflictingServerVersion:(BOOL)overwriteConflicting{

    
    //Download new attachment metadata
    
    //TODO: Refactor this to call ZPCacheController instead so that the response from the server is stored in the DB. 
    NSArray* attachments = [[ZPServerConnection instance] retrieveItemsFromLibrary:attachment.libraryID itemKeys:[NSArray arrayWithObject:attachment.key]];

    //Original was not found
    if([attachments count]==0){
        DDLogWarn(@"Retrieving updated item %@ from library %i resulted in empty response",attachment.key,attachment.libraryID);
        
        NSError* error = [[NSError alloc] initWithDomain:@"ZotPad" code:1 userInfo:[NSDictionary dictionaryWithObject:@"Original item does not exists on Zotero server." forKey:NSLocalizedDescriptionKey]];
        [[ZPServerConnection instance] failedUploadingAttachment:attachment withError:error usingFileChannel:self toURL:NULL];

    }
    else{
        
        //Get new data
        attachment = [attachments objectAtIndex:0];

        //Store data about the file in the user info so that it is always available
        
        NSString* path = attachment.fileSystemPath_modified;
        NSDictionary* documentFileAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:NULL];
        NSTimeInterval timeModified = [[documentFileAttributes fileModificationDate] timeIntervalSince1970];
        long long timeModifiedMilliseconds = (long long) trunc(timeModified * 1000.0f);
        NSString* md5 = [ZPZoteroAttachment md5ForFileAtPath:path];
        
        NSMutableDictionary* userInfo= [[NSMutableDictionary alloc]initWithCapacity:3];
        [userInfo setObject:attachment forKey:@"attachment"];
        [userInfo setObject:[NSNumber numberWithLongLong:timeModifiedMilliseconds] forKey:@"mtime"];
        [userInfo setObject:md5 forKey:@"md5"];
        [userInfo setObject:[NSNumber numberWithBool:overwriteConflicting] forKey:@"overwriteConflicting"];
        
        
        if(! [attachment.md5 isEqualToString:attachment.versionIdentifier_local] && ! overwriteConflicting){
            
            //Conflict
            
            //If the version that we have downloaded from the server is different than what exists on the server now, delete the local copy
            if(! [attachment.md5 isEqualToString:attachment.versionIdentifier_server]){
                
                DDLogWarn(@"Removing cached copy of file %@ because the local (%@) and server (%@) version identifiers differ.",attachment.filename,attachment.versionIdentifier_server,attachment.md5);
                
                [attachment purge_original:@"File is outdated (WebDAV pre-check)"];
                
            }
            [self presentConflictViewForAttachment:attachment];
            
        }
        else{
            [self _performWebDAVUploadForAttachment:attachment tag:ZPFILECHANNEL_WEBDAV_UPLOAD_FILE userInfo:userInfo];
        }
    }
}

-(void) _performWebDAVUploadForAttachment:(ZPZoteroAttachment*)attachment tag:(NSInteger)tag userInfo:(NSDictionary*) userInfo {
    
    //Setup the request 
    NSString* WebDAVRoot = [ZPPreferences webDAVURL];
    NSString* key =  attachment.key;
    NSString* urlString;
    if(tag == ZPFILECHANNEL_WEBDAV_UPLOAD_FILE){
        urlString = [WebDAVRoot stringByAppendingFormat:@"/%@.zip",key];
    }
    else if(tag == ZPFILECHANNEL_WEBDAV_UPLOAD_UPDATE_PROP){
        urlString = [WebDAVRoot stringByAppendingFormat:@"/%@.prop",key];
    }
    else if(tag == ZPFILECHANNEL_WEBDAV_UPLOAD_UPDATE_LASTSYNC){
        urlString = [WebDAVRoot stringByAppendingString:@"/lastsync"];
    }
    
    NSURL *url = [NSURL URLWithString:urlString]; 
    
    DDLogInfo(@"Uploading file %@ to WebDAV address %@",attachment.filename, urlString);
    
    ASIHTTPRequest *uploadRequest = [ASIHTTPRequest requestWithURL:url]; 
    
    [self linkAttachment:attachment withRequest:uploadRequest];
    
    //For some reason authentication using digest fails if persistent connections are in use
    [uploadRequest setShouldAttemptPersistentConnection:NO];
    [uploadRequest setShouldPresentAuthenticationDialog:YES];
    [uploadRequest setUseKeychainPersistence:YES];
    [uploadRequest setDelegate:self];
    uploadRequest.userInfo = userInfo;
    uploadRequest.tag = tag;
    
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* hostException = [defaults objectForKey:@"webdavsecurityexception"];
    if([[url host] isEqual:hostException]){
        [uploadRequest setValidatesSecureCertificate:NO];
    }

    
    if(tag == ZPFILECHANNEL_WEBDAV_UPLOAD_FILE){
        //Zip the file before uploading
        
        ZipArchive* zipArchive = [[ZipArchive alloc] init];
        
        NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%f",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
        
        [zipArchive CreateZipFile2:tempFile];
        [zipArchive addFileToZip:attachment.fileSystemPath_modified newname:attachment.filenameZoteroBase64Encoded];
        [zipArchive CloseZipFile2];
        
        [uploadRequest appendPostDataFromFile:tempFile];
        [[NSFileManager defaultManager] removeItemAtPath:tempFile error:NULL];
    }
    else if(tag == ZPFILECHANNEL_WEBDAV_UPLOAD_UPDATE_PROP){
        [uploadRequest appendPostData:[[NSString stringWithFormat:@"<properties version=\"1\">\n  <mtime>%@</mtime>\n  <hash>%@</hash>\n</properties>",
                                        [userInfo objectForKey:@"mtime"], [userInfo objectForKey:@"md5"]] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    else if(tag == ZPFILECHANNEL_WEBDAV_UPLOAD_UPDATE_LASTSYNC){
        [uploadRequest appendPostData:[@"1" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [uploadRequest setRequestMethod:@"PUT"];
    
    [uploadRequest startAsynchronous];
    
}


-(void) _registerWebDAVUploadWithZoteroServer:(ZPZoteroAttachment*)attachment userInfo:(NSDictionary*) userInfo{
    
    //Start uploading item metadata
    
    NSString* oauthkey =  [ZPPreferences OAuthKey];
    NSString* urlString = [NSString stringWithFormat:@"https://api.zotero.org/users/%@/items/%@?key=%@",[ZPPreferences userID],attachment.key, oauthkey];
    
    ASIHTTPRequest* request = [[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    
    request.userInfo = userInfo;
    request.tag = ZPFILECHANNEL_WEBDAV_UPLOAD_REGISTER;
    request.delegate = self;
    
    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request addRequestHeader:@"If-Match" value:attachment.etag];
    
    //Update the JSON
    NSDictionary* oldJsonContent = (NSDictionary*) [attachment.jsonFromServer JSONValue];
    NSMutableDictionary* jsonContent = [NSMutableDictionary dictionaryWithDictionary:oldJsonContent];
    
    [jsonContent setObject:[userInfo objectForKey:@"md5"] forKey:@"md5"];
    [jsonContent setObject:[userInfo objectForKey:@"mtime"] forKey:@"mtime"];
    
    
    NSString* jsonString = [jsonContent JSONRepresentation];
    [request appendPostData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]];
    request.requestMethod = @"PUT";
    
    DDLogInfo(@"Uploading metadata about new version (%@) of file %@ to Zotero ",[userInfo objectForKey:@"md5"],attachment.filename);
    
    [request startAsynchronous];
}

-(void) useProgressView:(UIProgressView*) progressView forUploadingAttachment:(ZPZoteroAttachment*)attachment{
    
    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    DDLogVerbose(@"Upload ProgressView %@ for request %@ with tag %i",progressView,request,request.tag);
    
    if(request != NULL){
        if(request.tag == ZPFILECHANNEL_WEBDAV_UPLOAD_FILE){
            [request setUploadProgressDelegate:progressView];
        }
    }
}


-(void) removeProgressView:(UIProgressView*) progressView{

    for(ASIHTTPRequest* request in [self allRequests]){
        if(request.uploadProgressDelegate==progressView){
            request.uploadProgressDelegate = NULL;
        }
        else if(request.downloadProgressDelegate!= NULL){
            ZPFileChannel_WebDAV_ProgressDelegate* delegate = (ZPFileChannel_WebDAV_ProgressDelegate*) request.downloadProgressDelegate;
            if(delegate.progressView == progressView){
                request.downloadProgressDelegate = NULL;
            }
        }
    }
}


#pragma mark - Callbacks

- (void)requestFinished:(ASIHTTPRequest *)request{
    
    ZPZoteroAttachment* attachment = [request.userInfo objectForKey:@"attachment"];
    
    if(request.tag == ZPFILECHANNEL_WEBDAV_DOWNLOAD){

        if(request.responseStatusCode == 200){
            //TODO: A more robust way to check if we need to uncompress
            if(attachment.linkMode == LINK_MODE_IMPORTED_URL && (
                                                                            [attachment.contentType isEqualToString:@"text/html"] ||
                                                                            [attachment.contentType isEqualToString:@"application/xhtml+xml"])){
                NSString* tempFile = [request downloadDestinationPath];
                NSString* md5 = [ZPZoteroAttachment md5ForFileAtPath:tempFile];
                DDLogVerbose(@"The MD5 sum of the file received from server is %@", md5);
                [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:tempFile withVersionIdentifier:md5 usingFileChannel:self];
            }
            
            else {
                //Unzip the attachment
                ZipArchive* zipArchive = [[ZipArchive alloc] init];
                [zipArchive UnzipOpenFile:[request downloadDestinationPath]];
                
                NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%f",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
                
                [zipArchive UnzipFileTo:tempFile overWrite:YES];
                [zipArchive UnzipCloseFile];

                //If there was only one file in the archive, use that
                
                NSArray* fileArray= [[NSFileManager defaultManager]contentsOfDirectoryAtPath:tempFile error:NULL];
                
                //Traverse a file hierarchy if this is a folderr
                
                BOOL firstFileIsDirectory = FALSE;
                
                while([fileArray count] == 1){
                    
                    BOOL firstFileExists = [[NSFileManager defaultManager] fileExistsAtPath:[tempFile stringByAppendingPathComponent:[fileArray objectAtIndex:0]]
                                                                           isDirectory:&firstFileIsDirectory];
                    
                    if(firstFileExists && firstFileIsDirectory){   
                        DDLogWarn(@"WebDAV archive contained a directory instead of a file.");
                        tempFile = [tempFile stringByAppendingPathComponent:[fileArray objectAtIndex:0]];
                        fileArray= [[NSFileManager defaultManager]contentsOfDirectoryAtPath:tempFile error:NULL];
                    }
                    else break;
                }
                       
                if([fileArray count]==1){
                    tempFile = [tempFile stringByAppendingPathComponent:[fileArray objectAtIndex:0]];

                    //check if this is a folder instead of a file 
                    
                    NSString* md5 = [ZPZoteroAttachment md5ForFileAtPath:tempFile];
                    DDLogVerbose(@"The MD5 sum of the file received from server is %@", md5);
                    [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:tempFile withVersionIdentifier:md5 usingFileChannel:self];
                }
                else if([fileArray count]==0){
                    NSString* errorMessage = [NSString stringWithFormat:@"Zip file downloaded from WebDAV URL %@ did not contain any files (%@)",[request.url absoluteString], attachment.filename];
                    
                    DDLogError(errorMessage);
                    
                    NSError* error = [[NSError alloc] initWithDomain:[request.url host] code:request.responseStatusCode userInfo:[NSDictionary dictionaryWithObject:errorMessage forKey:NSLocalizedDescriptionKey]];
                    [[ZPServerConnection instance] failedDownloadingAttachment:attachment withError:error usingFileChannel:self fromURL:[request.url absoluteString]];
                }
                else{
                    //Check that the file that we wanted exits
                    NSString* encodedFileName = attachment.filenameZoteroBase64Encoded;
                    tempFile = [tempFile stringByAppendingPathComponent:encodedFileName];
                                        
                    if(![[NSFileManager defaultManager] fileExistsAtPath:tempFile]){
                        NSString* errorMessage = [NSString stringWithFormat:@"Zip file downloaded from WebDAV URL %@ contained several files, but none matched %@ (%@)",[request.url absoluteString], attachment.filenameZoteroBase64Encoded,attachment.filename];
                        
                        DDLogError(errorMessage);
                        
                        NSError* error = [[NSError alloc] initWithDomain:[request.url host] code:request.responseStatusCode userInfo:[NSDictionary dictionaryWithObject:errorMessage forKey:NSLocalizedDescriptionKey]];
                        [[ZPServerConnection instance] failedDownloadingAttachment:attachment withError:error usingFileChannel:self fromURL:[request.url absoluteString]];
                    }
                    else{
                        NSString* md5 = [ZPZoteroAttachment md5ForFileAtPath:tempFile];
                        DDLogVerbose(@"The MD5 sum of the file received from server is %@", md5);
                        [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:tempFile withVersionIdentifier:md5 usingFileChannel:self];
                    }
                }
            }
        }
        
        else{
            NSError* error = [[NSError alloc] initWithDomain:[request.url host] code:request.responseStatusCode userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"WebDAV request to %@ returned %@",request.url,request.responseStatusMessage] forKey:NSLocalizedDescriptionKey]];
            [[ZPServerConnection instance] failedDownloadingAttachment:attachment withError:error usingFileChannel:self fromURL:[request.url absoluteString]];
        }        
        

        
        [self cleanupAfterFinishingAttachment:attachment];
    }
    
    // Uploads 
    
    else {
        
        
        if(request.tag == ZPFILECHANNEL_WEBDAV_UPLOAD_FILE && (request.responseStatusCode == 204 || request.responseStatusCode == 201)){
            [self _performWebDAVUploadForAttachment:attachment tag:ZPFILECHANNEL_WEBDAV_UPLOAD_UPDATE_PROP userInfo:request.userInfo];
        }        
        else if(request.tag == ZPFILECHANNEL_WEBDAV_UPLOAD_UPDATE_PROP && (request.responseStatusCode == 204 || request.responseStatusCode == 201)){
            [self _performWebDAVUploadForAttachment:attachment tag:ZPFILECHANNEL_WEBDAV_UPLOAD_UPDATE_LASTSYNC userInfo:request.userInfo];
        }
        else if(request.tag == ZPFILECHANNEL_WEBDAV_UPLOAD_UPDATE_LASTSYNC &&  (request.responseStatusCode == 204 || request.responseStatusCode == 201)){
            [self _registerWebDAVUploadWithZoteroServer:attachment userInfo:request.userInfo];   
        }
        
        else if(request.tag == ZPFILECHANNEL_WEBDAV_UPLOAD_REGISTER && request.responseStatusCode == 200){
            
            //DDLogVerbose([self requestDumpAsString:request]);
            //All done
            [[ZPServerConnection instance] finishedUploadingAttachment:attachment withVersionIdentifier:[request.userInfo objectForKey:@"md5"]];
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
            }
            [self presentConflictViewForAttachment:attachment];
        }
        else{
            NSError* error =[NSError errorWithDomain:request.url.host code:request.responseStatusCode userInfo:[NSDictionary dictionaryWithObject:request.responseStatusMessage forKey:NSLocalizedDescriptionKey]];
            [self cleanupAfterFinishingAttachment:attachment];
            [[ZPServerConnection instance] failedUploadingAttachment:attachment withError:error usingFileChannel:self toURL:[request.url absoluteString]];
        }
    }
}

- (void)requestFailed:(ASIHTTPRequest *)request{
    NSError *error = [request error];

    ZPZoteroAttachment* attachment = [request.userInfo objectForKey:@"attachment"];

    DDLogError(@"Request to %@ failed: %@", request.url, [error description]);

    //Connection error
    if(error.code ==ASIConnectionFailureErrorType){
        //SSL error (self signed certificate)
        // errSSLXCertChainInvalid
        NSError* underlyingError = [error.userInfo objectForKey:NSUnderlyingErrorKey];
        if(underlyingError.code == -9807){
            UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"SSL certificate error"
                                                              message:[NSString stringWithFormat: @"%@ did not provide a valid SSL certificate or the signature verification failed. If you are using a self-signed certificate and understand what you are doing, you can add a security exception and choose to trust the site.",[request.url host]]
                                                             delegate:self
                                                    cancelButtonTitle:@"Cancel"
                                                    otherButtonTitles:@"Disable WebDAV",@"Add security exception",nil];
            
            [message show];
            
        }
        
    }
    //If there was an authentication issue, reauthenticate
    else if(error.code == ASIAuthenticationErrorType){
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Authentication failed"
                                                          message:@"Authenticating with WebDAV server failed."
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                                otherButtonTitles:@"Disable WebDAV",nil];
        
        [message show];
    }
    else if(error.code == ASIUnableToCreateRequestErrorType){
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Configuration error"
                                                          message:@"WebDAV addresss is not configured properly. Please check ZotPad settings."
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                                otherButtonTitles:@"Disable WebDAV",nil];
        
        [message show];
    }
    
    if(request.tag == ZPFILECHANNEL_WEBDAV_DOWNLOAD){
        [[ZPServerConnection instance] failedDownloadingAttachment:attachment withError:error usingFileChannel:self fromURL:[request.url absoluteString]];
    }
    else{
        [[ZPServerConnection instance] failedUploadingAttachment:attachment withError:error usingFileChannel:self toURL:[request.url absoluteString]];
    }
    
    [self cleanupAfterFinishingAttachment:attachment];
}

-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment *)attachment{
    @synchronized(downloadProgressDelegates){
        [downloadProgressDelegates removeObjectForKey:attachment.key];
    }

}
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    //Disable webdav
    if(buttonIndex == 1){
        [ZPPreferences setUseWebDAV:FALSE];
    }
    //Add security exception
    else if(buttonIndex == 2){
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSString* host = [[NSURL URLWithString:[ZPPreferences webDAVURL]] host]; 
        [defaults setObject:host forKey:@"webdavsecurityexception"];
    }
}


@end
