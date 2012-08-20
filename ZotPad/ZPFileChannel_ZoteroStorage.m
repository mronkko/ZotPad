//
//  ZPFileChannel_ZoteroStorage.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
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
- (ASIHTTPRequest*) _baseRequestForAttachment:(ZPZoteroAttachment*)attachment type:(NSInteger)type overWriteConflictingServerVersion:(BOOL)overwriteConflicting;

@end

@implementation ZPFileChannel_ZoteroStorage

-(int) fileChannelType{
    return VERSION_SOURCE_ZOTERO;
}



- (ASIHTTPRequest*) _baseRequestForAttachment:(ZPZoteroAttachment*)attachment type:(NSInteger)type overWriteConflictingServerVersion:(BOOL)overwriteConflicting{
   
    
    if(attachment.key == NULL){
        [NSException raise:@"Attachment key cannot be null" format:@""];
    }
    
    //Create the download URL
    NSString* oauthkey =  [ZPPreferences OAuthKey];
    NSString* urlString;
    NSInteger libraryID= attachment.libraryID;
    
    if(libraryID==1 || libraryID == 0){
        urlString = [NSString stringWithFormat:@"https://api.zotero.org/users/%@",[ZPPreferences userID]];
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
        
        //If we are overwriting a conflicting file, just use the metadata md5 instead of the md5 that we have received
        
        if(overwriteConflicting){
            [request addRequestHeader:@"If-Match" value:attachment.md5];
        }
        else {
            [request addRequestHeader:@"If-Match" value:attachment.versionIdentifier_server];
        }
    }
    
    [self linkAttachment:attachment withRequest:request];
    
    //Easier to just always use accurate progress. There should not be a significant performance penalty
    request.showAccurateProgress=TRUE;
    request.delegate = self;
    request.tag = type;

    return request;
}

#pragma mark - Downloading


-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{

    
    ASIHTTPRequest* request = [self _baseRequestForAttachment:attachment type:ZPFILECHANNEL_ZOTEROSTORAGE_DOWNLOAD overWriteConflictingServerVersion:FALSE];
    request.userInfo = [NSDictionary dictionaryWithObject:attachment forKey:@"attachment"];
    
    NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%f",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
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


-(void) startUploadingAttachment:(ZPZoteroAttachment*)attachment overWriteConflictingServerVersion:(BOOL)overwriteConflicting{
    
    ASIHTTPRequest* request = [self _baseRequestForAttachment:attachment type:ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_AUTHORIZATION overWriteConflictingServerVersion:YES];

    // Get info about the file to be uploaded
    
    NSString* path = attachment.fileSystemPath_modified;
    NSDictionary* documentFileAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:NULL];
    NSTimeInterval timeModified = [[documentFileAttributes fileModificationDate] timeIntervalSince1970];
    long long timeModifiedMilliseconds = (long long) trunc(timeModified * 1000.0f);
    
    
    NSString* md5 = [ZPZoteroAttachment md5ForFileAtPath:path];

    [attachment logFileRevisions];

    // Get upload authorization
     
    
    
    NSString* postBodyString = [NSString stringWithFormat:@"md5=%@&filename=%@&filesize=%llu&mtime=%lli",
                                md5,
                                attachment.filename,
                                [documentFileAttributes fileSize],
                                timeModifiedMilliseconds ];


    NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] initWithCapacity:3];
    [userInfo setObject:attachment forKey:@"attachment"];
    [userInfo setObject:md5 forKey:@"md5"];
    [userInfo setObject:[NSNumber numberWithBool:overwriteConflicting] forKey:@"overwriteConflicting"];
    
    request.userInfo = userInfo;
    
    if(attachment.contentType != NULL){
        postBodyString = [postBodyString stringByAppendingFormat:@"&contentType=%@",attachment.contentType];
        if(attachment.charset != NULL){
            postBodyString = [postBodyString stringByAppendingFormat:@"&charset=%@",attachment.charset];
        }
        else {
            postBodyString = [postBodyString stringByAppendingFormat:@"&charset="];
        }
    }
    postBodyString = [postBodyString stringByAppendingFormat:@"&params=1"];
    
    
    [request setPostBody:[NSMutableData dataWithData:[postBodyString dataUsingEncoding:NSUTF8StringEncoding]]];
     
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
        
        [ZPServerConnection finishedDownloadingAttachment:attachment toFileAtPath:[request downloadDestinationPath] withVersionIdentifier:versionIdentifier usingFileChannel:self];
        
        [self cleanupAfterFinishingAttachment:attachment];
    }
    else{
                
        if(request.tag == ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_AUTHORIZATION && request.responseStatusCode == 200){
            
            
            
            if([[request responseString] isEqualToString:@"{\"exists\":1}"]){
                //Finish uploading the attachment

                DDLogWarn(@"Upload of file %@ was declined by Zotero server because the file exists already on the Zotero server",attachment.filename);
                
                [ZPServerConnection finishedUploadingAttachment:attachment withVersionIdentifier:attachment.versionIdentifier_local];
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
                uploadRequest.showAccurateProgress=TRUE;
                
                NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] initWithDictionary:request.userInfo];
                [userInfo setObject:[responseDictionary objectForKey:@"uploadKey"] forKey:@"uploadKey"];
                uploadRequest.userInfo = userInfo;
                
                if([(NSNumber*) [request.userInfo objectForKey:@"overwriteConflicting"] boolValue]){
                    [request addRequestHeader:@"If-Match" value:attachment.md5];
                }
                else {
                    [request addRequestHeader:@"If-Match" value:attachment.versionIdentifier_server];
                }

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
            ASIHTTPRequest* registerRequest = [self _baseRequestForAttachment:attachment type:ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_REGISTER overWriteConflictingServerVersion:[(NSNumber*)[request.userInfo objectForKey:@"overwriteConflicting"] boolValue]];
            registerRequest.userInfo = request.userInfo;
            [registerRequest setPostBody:[NSMutableData dataWithData:[[NSString stringWithFormat:@"upload=%@",[request.userInfo objectForKey:@"uploadKey"]] dataUsingEncoding:NSASCIIStringEncoding]]];
            [registerRequest startAsynchronous];
                
        }
        else if(request.tag == ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_REGISTER && request.responseStatusCode == 204){
            
            DDLogInfo(@"New version of file %@ registered succesfully with Zotero server",attachment.filename);

            //All done
            [ZPServerConnection finishedUploadingAttachment:attachment withVersionIdentifier:[request.userInfo objectForKey:@"md5"]];
            [self cleanupAfterFinishingAttachment:attachment];
        }
        else if(request.responseStatusCode == 412){

            DDLogWarn(@"Zotero server reported a version conflict with file %@",attachment.filename);
            //Conflict. 
                        
            //TODO: Refactor this to call ZPCacheController instead so that the response from the server is stored in the DB. 
            
            attachment = [[ZPServerConnection retrieveItemsFromLibrary:attachment.libraryID itemKeys:[NSArray arrayWithObject:attachment.key]] objectAtIndex:0];
            [attachment logFileRevisions];
            
            //If the version that we have downloaded from the server is different than what exists on the server now, delete the local copy
            if(! [attachment.md5 isEqualToString:attachment.versionIdentifier_server]){
                DDLogInfo(@"New metadate MD5 (%@) and cached MD5 (%@) differ",attachment.md5,attachment.versionIdentifier_server);
                [attachment purge_original:@"File is outdated (Zotero storage conflict)"];
            }
            [self presentConflictViewForAttachment:attachment];
        }
        else {
            NSError* error =[NSError errorWithDomain:@"zotero.org" code:request.responseStatusCode userInfo:NULL];
            DDLogError(@"Uploading file %@ to Zotero server failed with error: %@",attachment.filename,request.responseStatusMessage);
            [self cleanupAfterFinishingAttachment:attachment];
            [ZPServerConnection failedUploadingAttachment:attachment withError:error usingFileChannel:self toURL:[request.url absoluteString]];
        }
    }
}

-(void) cancelUploadingAttachment:(ZPZoteroAttachment*)attachment{
    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    if(request != NULL){
        [request cancel];
    }
    [self cleanupAfterFinishingAttachment:attachment];
    
    [ZPServerConnection canceledUploadingAttachment:attachment usingFileChannel:self];
}

- (void)requestFailed:(ASIHTTPRequest *)request{
        
    NSError *error = [request error];
    ZPZoteroAttachment* attachment = [request.userInfo objectForKey:@"attachment"];
    
    if(request.tag == ZPFILECHANNEL_ZOTEROSTORAGE_DOWNLOAD){
        DDLogError(@"Downloading file %@ from Zotero server failed with error: %@",attachment.filename, [error description]);
        [ZPServerConnection failedDownloadingAttachment:attachment withError:error usingFileChannel:self fromURL:[request.url absoluteString]];
    }
    else{
        DDLogError(@"Uploading failed %@ to Zotero server failed with error: %@",attachment.filename, [error description]);
        [ZPServerConnection failedUploadingAttachment:attachment withError:error usingFileChannel:self toURL:[request.url absoluteString]];
    }
    
    //DDLogVerbose([self requestDumpAsString:request]);

    [self cleanupAfterFinishingAttachment:attachment];

}

-(void) removeProgressView:(UIProgressView*) progressView{
    
    for(ASIHTTPRequest* request in [self allRequests]){
        if(request.uploadProgressDelegate==progressView){
            request.uploadProgressDelegate = NULL;
        }
        else if(request.downloadProgressDelegate == progressView){
            request.downloadProgressDelegate = NULL;
        }
        
        if([request.userInfo objectForKey:@"progressView"] == progressView){
            NSMutableDictionary* newUserInfo = [[NSMutableDictionary alloc] init];
            
            for(NSString* key in request.userInfo){
                if(! [key isEqualToString:@"progressView"]){
                    [newUserInfo setObject:[request.userInfo objectForKey:key] forKey:key];
                }
            }
            request.userInfo = newUserInfo;
        }
    }
}



@end
