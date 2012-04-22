
//
//  ZPFileChannel_WebDAV.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPFileChannel_WebDAV.h"
#import "ZPPreferences.h"
#import "KeychainItemWrapper.h"
#import "ZPServerConnection.h"
#import "ASIHTTPRequest.h"

//Unzipping and base64 decoding
#import "ZipArchive.h"
#import "QSStrings.h"

@implementation ZPFileChannel_WebDAV


-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    //Only My Library may be stored on WebDAV
    NSLog(@"Checking WebDAV");
    if([[ZPPreferences instance] useWebDAV]){
        
        NSLog(@"WebDAV is enabled. The library ID for item with key %@ is %@",
              attachment.key,
              attachment.libraryID);
        
        if([attachment.libraryID intValue]==1){
        
            NSLog(@"The item is from My Library, proceeding with WebDAV download");
            
            //Setup the request 
            NSString* WebDAVRoot = [[ZPPreferences instance] webDAVURL];
            NSString* key =  attachment.key;
            NSString* urlString = [WebDAVRoot stringByAppendingFormat:@"/%@.zip",key];
            NSURL *url = [NSURL URLWithString:urlString]; 
            
            NSLog(@"Downloading from WebDAV %@",urlString);
            
            ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url]; 
            
            [self linkAttachment:attachment withRequest:request];
            
            //Easier to just always use accurate progress. There should not be a significant performance penalty
            request.showAccurateProgress=TRUE;
            
            NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
            [request setDownloadDestinationPath:tempFile];

            //For some reason authentication using digest fails if persistent connections are in use
            [request setShouldAttemptPersistentConnection:NO];
            [request setShouldPresentAuthenticationDialog:YES];
            [request setUseKeychainPersistence:YES];
            [request setRequestMethod:@"GET"];
            [request setDelegate:self];
            [request startAsynchronous];
            
        }
    }
    // If WebDAV is not in use, just notify that we are done
    else [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:NULL usingFileChannel:self];
    
}
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    
    if(request != NULL){
        [request cancel];
        [self cleanupAfterFinishingAttachment:attachment];
    }
}
-(void) useProgressView:(UIProgressView*) progressView forAttachment:(ZPZoteroAttachment*)attachment{
    
    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    
    if(request != NULL){
        [request setDownloadProgressDelegate:progressView];
    }
}

- (void)requestFinished:(ASIHTTPRequest *)request{
    ZPZoteroAttachment* attachment = [self attachmentWithRequest:request];
    
    NSString* tempFile; 
    //Everything that is not linked_url needs to be unzipped
    if(! [attachment.linkMode isEqualToString:@"imported_url"] ){

    //Unzip the attachment
        ZipArchive* zipArchive = [[ZipArchive alloc] init];
        [zipArchive UnzipOpenFile:[request downloadDestinationPath]];
        
        tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
        
        [zipArchive UnzipFileTo:tempFile overWrite:YES];
        [zipArchive UnzipCloseFile];
        
        
    }
    else {
        tempFile = [request downloadDestinationPath];
    }

    [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:tempFile usingFileChannel:self];
    
    [self cleanupAfterFinishingAttachment:attachment];
}

- (void)requestFailed:(ASIHTTPRequest *)request{
    NSError *error = [request error];
    NSLog(@"File download from Zotero server failed: %@",[error description]);

    ZPZoteroAttachment* attachment = [self attachmentWithRequest:request];
    
    //If there was an authentication issue, reauthenticat
    if(error.code == 3){
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Authentication failed"
                                                          message:@"Authenticating with WebDAV server failed."
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                                otherButtonTitles:@"Disable WebDAV",nil];
        
        [message show];
    }
    else{
        [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:NULL usingFileChannel:self];
        [self cleanupAfterFinishingAttachment:attachment];
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
