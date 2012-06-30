//
//  ZPFileChannel_ZoteroStorage.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPCore.h"

#import "ZPFileChannel_ZoteroStorage.h"
#import "ZPPreferences.h"
#import "ASIFormDataRequest.h"

#import "ZPServerConnection.h"
#import "ZPDatabase.h"
#import "SBJson.h"


NSInteger const ZPFILECHANNEL_ZOTEROSTORAGE_DOWNLOAD = 1;
NSInteger const ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_AUTHORIZATION = 2;
NSInteger const ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_FILE = 3;
NSInteger const ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_REGISTER = 4;


@interface ZPFileChannel_ZoteroStorage()
- (ASIHTTPRequest*) _baseRequestForAttachment:(ZPZoteroAttachment*)attachment type:(NSInteger)type;
- (NSString*) _versionIdentifierForAttachment:(ZPZoteroAttachment*)attachment;
@end

@implementation ZPFileChannel_ZoteroStorage

-(int) fileChannelType{
    return VERSION_SOURCE_ZOTERO;
}

- (NSString*) _versionIdentifierForAttachment:(ZPZoteroAttachment*)attachment{
    
    NSString* versionIdentifier = attachment.versionIdentifier_local;
    
    // Fall back on the server version identifier 
    if(versionIdentifier == [NSNull null]){
        versionIdentifier = attachment.versionIdentifier_server;
    }
    //Further fallback
    if(versionIdentifier == [NSNull null]){
        versionIdentifier = attachment.md5;
    }
    
    return  versionIdentifier;
}

- (ASIHTTPRequest*) _baseRequestForAttachment:(ZPZoteroAttachment*)attachment type:(NSInteger)type{
   
    
    if(attachment.key == [NSNull null]){
        [NSException raise:@"Attachment key cannot be null" format:@""];
    }
    
    //Create the download URL
    NSString* oauthkey =  [[ZPPreferences instance] OAuthKey];
    NSString* urlString;
    NSInteger libraryID= [attachment.libraryID intValue];
    
    if(libraryID==1 || libraryID == 0){
        urlString = [NSString stringWithFormat:@"https://api.zotero.org/users/%@",[[ZPPreferences instance] userID]];
    }
    else{
        urlString = [NSString stringWithFormat:@"https://api.zotero.org/groups/%i",libraryID];        
    }

    urlString = [NSString stringWithFormat:@"%@/items/%@/file",urlString, attachment.key];

    ASIHTTPRequest *request;

    urlString = [NSString stringWithFormat:@"%@?key=%@",urlString, oauthkey];
    

    NSURL* url = [NSURL URLWithString:urlString];

    request = [ASIHTTPRequest requestWithURL:url];

    if(type != ZPFILECHANNEL_ZOTEROSTORAGE_DOWNLOAD){
        request.requestMethod = @"POST";
        [request addRequestHeader:@"Content-Type" value:@"application/x-www-form-urlencoded"];
        [request addRequestHeader:@"If-Match" value:[self _versionIdentifierForAttachment:attachment]];
    }
    
    [self linkAttachment:attachment withRequest:request];
    
    //Easier to just always use accurate progress. There should not be a significant performance penalty
    request.showAccurateProgress=TRUE;
    request.delegate = self;
    request.tag = type;
    request.userInfo = [NSDictionary dictionaryWithObject:attachment forKey:@"attachment"];

    return request;
}

#pragma mark - Downloading


-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{

    
    ASIHTTPRequest* request = [self _baseRequestForAttachment:attachment type:ZPFILECHANNEL_ZOTEROSTORAGE_DOWNLOAD];
    
    NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
    [request setDownloadDestinationPath:tempFile];
    [request startAsynchronous];

    DDLogInfo(@"Downloading %@ from Zotero started",attachment.filename);

   
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
        [request setDownloadProgressDelegate:progressView];
    }
}

#pragma mark - Uploading


-(void) startUploadingAttachment:(ZPZoteroAttachment*)attachment{

    ASIHTTPRequest* request = [self _baseRequestForAttachment:attachment type:ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_AUTHORIZATION];

    // Get info about the file to be uploaded
    
    NSString* path = attachment.fileSystemPath_modified;
    NSDictionary* documentFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES];
    NSTimeInterval timeModified = [[documentFileAttributes fileModificationDate] timeIntervalSince1970];
    long long timeModifiedMilliseconds = (long long) trunc(timeModified * 1000.0f);
    
    
    NSString* md5 = [attachment md5ForFileAtPath:path];
    
    // Get upload authorization
     
    
    
    NSString* postBodyString = [NSString stringWithFormat:@"md5=%@&filename=%@&filesize=%llu&mtime=%lli",
                                md5,
                                attachment.filename,
                                [documentFileAttributes fileSize],
                                timeModifiedMilliseconds ];

    DDLogVerbose(@"MD5s for file %@ are old: %@ new: %@",attachment.filename,[self _versionIdentifierForAttachment:attachment],md5);

    NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] initWithDictionary:request.userInfo];
    [userInfo setObject:md5 forKey:@"md5"];
    request.userInfo = userInfo;
    
    if(attachment.contentType != [NSNull null]){
        postBodyString = [postBodyString stringByAppendingFormat:@"&contentType=%@",attachment.contentType];
        if(attachment.charset != [NSNull null]){
            postBodyString = [postBodyString stringByAppendingFormat:@"&charset=%@",attachment.charset];
        }
        else {
            postBodyString = [postBodyString stringByAppendingFormat:@"&charset="];
        }
    }
    postBodyString = [postBodyString stringByAppendingFormat:@"&params=1"];
    
    
    [request setPostBody:[postBodyString dataUsingEncoding:NSUTF8StringEncoding]];
     
    [request startAsynchronous];
    
}

-(void) useProgressView:(UIProgressView*) progressView forUploadingAttachment:(ZPZoteroAttachment*)attachment{

    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    
    if(request != NULL){
        if(request.tag == ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_FILE){
            [request setUploadProgressDelegate:progressView];
        }
        else{
            NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:request.userInfo];
            [dict setObject:progressView forKey:@"progressView"];
            request.userInfo = dict;
        }
    }
}

#pragma mark - Call backs

- (void)requestFinished:(ASIHTTPRequest *)request{
    
//    NSString* dump =[self requestDumpAsString:request];
//    DDLogVerbose(dump);
    
    ZPZoteroAttachment* attachment = [request.userInfo objectForKey:@"attachment"];
    
    if(request.tag == ZPFILECHANNEL_ZOTEROSTORAGE_DOWNLOAD){
        DDLogInfo(@"Downloading %@ from Zotero succesfully finished",attachment.filename);
        
        NSString* versionIdentifier = [[[request responseHeaders] objectForKey:@"Etag"] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        
        [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:[request downloadDestinationPath] withVersionIdentifier:versionIdentifier usingFileChannel:self];
        
        [self cleanupAfterFinishingAttachment:attachment];
    }
    else{
        
        if(request.tag == ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_AUTHORIZATION && request.responseStatusCode == 200){
            
            
            
            if([[request responseString] isEqualToString:@"{\"exists\":1}"]){
                //Finish uploading the attachment

                DDLogWarn(@"Upload of file %@ was declined by Zotero server because the file exists already on the Zotero server",attachment.filename);
                
                [[ZPServerConnection instance] finishedUploadingAttachment:attachment];
                //TODO: Should there be some kind of notification that the file was not uploaded because it already exists?
            }
            else{
                
                DDLogInfo(@"Upload of file %@ was atuhorized by Zotero server",attachment.filename);

                NSDictionary* responseDictionary = [[request responseString] JSONValue];
                
                //TODO: Attempt PATCH first and only do full upload as fallback option
                
                //POST the file
                NSString* urlString = [responseDictionary objectForKey:@"url"];

                ASIFormDataRequest* uploadRequest = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:urlString]];
                
                [self linkAttachment:attachment withRequest:request];
                
                uploadRequest.delegate = self;
                uploadRequest.tag = ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_FILE;
                
                NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] initWithDictionary:request.userInfo];
                [userInfo setObject:[responseDictionary objectForKey:@"uploadKey"] forKey:@"uploadKey"];
                uploadRequest.userInfo = userInfo;
                
                [uploadRequest addRequestHeader:@"If-Match" value:[self _versionIdentifierForAttachment:attachment]];
                
                NSDictionary* params = [responseDictionary objectForKey:@"params"];
                for(NSString *key in params){
                    NSString* value = [params objectForKey:key];
                    [uploadRequest addPostValue:[value stringByReplacingOccurrencesOfString:@"\"" withString:@""]
                                         forKey:[key stringByReplacingOccurrencesOfString:@"\"" withString:@""]];
                    
                }
                
                [uploadRequest setFile:attachment.fileSystemPath_modified forKey:@"file"];
                

                NSObject* progressDelegate = [uploadRequest.userInfo objectForKey:@"progressView"];
                
                if(progressDelegate != NULL){
                    uploadRequest.uploadProgressDelegate = progressDelegate;
                }
                
                //Remove this
                [uploadRequest startSynchronous];
            }
        }
        else if(request.tag == ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_FILE && request.responseStatusCode == 201){
            DDLogInfo(@"Uploading file %@ to Zotero server finished succesfully",attachment.filename);
                
                //Register upload
                ASIHTTPRequest* registerRequest = [self _baseRequestForAttachment:attachment type:ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_REGISTER];
                [registerRequest setPostBody:[[NSString stringWithFormat:@"upload=%@",[request.userInfo objectForKey:@"uploadKey"]] dataUsingEncoding:NSASCIIStringEncoding]];
                [registerRequest startAsynchronous];
                
        }
        else if(request.tag == ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_REGISTER && request.responseStatusCode == 204){
            
            DDLogInfo(@"New version of file %@ registered succesfully with Zotero server",attachment.filename);

            //All done
            [[ZPServerConnection instance] finishedUploadingAttachment:attachment];
            [self cleanupAfterFinishingAttachment:attachment];
        }
        else if(request.responseStatusCode == 412){

            DDLogWarn(@"Zotero server reported a version conflict with file %@",attachment.filename);
            //Conflict. 
            
            //Download new attachment metadata
            
            //TODO: Refactor this to call ZPCacheController instead so that the response from the server is stored in the DB. 
            
            attachment = [[[ZPServerConnection instance] retrieveItemsFromLibrary:attachment.libraryID itemKeys:[NSArray arrayWithObject:attachment.key]] objectAtIndex:0];

            //If the version that we have downloaded from the server is different than what exists on the server now, delete the local copy
            if(! [attachment.md5 isEqualToString:attachment.versionIdentifier_server]){
                [[NSFileManager defaultManager] removeItemAtPath:attachment.fileSystemPath_original error:NULL];
                attachment.versionIdentifier_server = attachment.md5;
                [[ZPDatabase instance] writeVersionInfoForAttachment:attachment];
            }
            [self presentConflictViewForAttachment:attachment];
        }
        else {
            NSError* error =[NSError errorWithDomain:@"zotero.org" code:request.responseStatusCode userInfo:NULL];
            DDLogError(@"Uploading file %@ to Zotero server failed with error: %@",attachment.filename,request.responseStatusMessage);
            [self cleanupAfterFinishingAttachment:attachment];
            [[ZPServerConnection instance] failedUploadingAttachment:attachment withError:error usingFileChannel:self];
        }
    }
}

-(void) cancelUploadingAttachment:(ZPZoteroAttachment*)attachment{
    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    if(request != NULL){
        [request cancel];
    }
    [self cleanupAfterFinishingAttachment:attachment];
    
    [[ZPServerConnection instance] canceledUploadingAttachment:attachment usingFileChannel:self];
}

- (void)requestFailed:(ASIHTTPRequest *)request{
    
    DDLogVerbose([self requestDumpAsString:request]);
    
    NSError *error = [request error];
    ZPZoteroAttachment* attachment = [request.userInfo objectForKey:@"attachment"];
    
    if(request.tag == ZPFILECHANNEL_ZOTEROSTORAGE_DOWNLOAD){
        DDLogError(@"Downloading file %@ from Zotero server failed with error: %@",attachment.filename, [error description]);
        [[ZPServerConnection instance] failedDownloadingAttachment:attachment withError:error usingFileChannel:self];
    }
    else{
        DDLogError(@"Uploading failed %@ to Zotero server failed with error: %@",attachment.filename, [error description]);
        [[ZPServerConnection instance] failedUploadingAttachment:attachment withError:error usingFileChannel:self];
    }
    [self cleanupAfterFinishingAttachment:attachment];

}



@end
