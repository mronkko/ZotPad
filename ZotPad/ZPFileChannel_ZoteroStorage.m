//
//  ZPFileChannel_ZoteroStorage.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//


#import "ZPCore.h"

#import "ZPFileChannel_ZoteroStorage.h"

#import "ASIFormDataRequest.h"
#import "ZPFileCacheManager.h"
#import "ZPServerConnection.h"

#import "SBJson.h"


NSInteger const ZPFILECHANNEL_ZOTEROSTORAGE_DOWNLOAD = 1;
NSInteger const ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_AUTHORIZATION = 2;
NSInteger const ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_FILE = 3;
NSInteger const ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_REGISTER = 4;


@interface ZPFileChannel_ZoteroStorage()
- (ASIHTTPRequest*) _baseRequestForAttachment:(ZPZoteroAttachment*)attachment type:(NSInteger)type overWriteConflictingServerVersion:(BOOL)overwriteConflicting;

@end

@implementation ZPFileChannel_ZoteroStorage

static NSOperationQueue* _downloadQueue;
static NSOperationQueue* _uploadQueue;

+(void) initialize{
    _downloadQueue = [[NSOperationQueue alloc] init];
    _uploadQueue = [[NSOperationQueue alloc] init];
}

+(NSInteger) activeDownloads{
    return [_downloadQueue operationCount];
}
+(NSInteger) activeUploads{
    return [_uploadQueue operationCount];
}

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
    
    if( libraryID== LIBRARY_ID_MY_LIBRARY ){
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
            if(attachment.md5 != NULL){
                [request addRequestHeader:@"If-Match" value:attachment.md5];
            }
            
            //This code should never run
            
            else{
                DDLogError(@"Attachment %@ (%@) is missing version identification information. The local file will replace the server version without a version check.",attachment.key,attachment.filename);
                [ZPServerConnection retrieveSingleItemWithKey:attachment.key fromLibraryWithID:attachment.libraryID completion:^(NSArray* attachmentList){
                    if(attachmentList.count == 1){
                        [self startUploadingAttachment:[attachmentList objectAtIndex:0] overWriteConflictingServerVersion:overwriteConflicting];
                    }
                    else{
                        DDLogError(@"Retrieving version information for attachment %@ (%@) during WebDAV upload resulted in %i results. The local file cannot be uploaded and will be purged.",attachment.filename, attachment.key,attachmentList.count);
                        [ZPFileCacheManager deleteModifiedFileForAttachment:attachment reason:@"Version information missing and server version does not exist"];
                    }
                }];
                [self cleanupAfterFinishingAttachment:attachment];
                return NULL;
            }

        }
        else {
            if(attachment.versionIdentifier_local == NULL){
                [self presentConflictViewForAttachment:attachment reason:@"Local version identifier missing"];
                [self cleanupAfterFinishingAttachment:attachment];
                return NULL;
            }
            [request addRequestHeader:@"If-Match" value:attachment.versionIdentifier_local];
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
    if(request == NULL) return;
    
    request.userInfo = [NSDictionary dictionaryWithObject:attachment forKey:ZPKEY_ATTACHMENT];
    
    NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%f",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
    [request setDownloadDestinationPath:tempFile];
    [_downloadQueue addOperation:request];

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
    
    [self logVersionInformationForAttachment: attachment];


    // Get info about the file to be uploaded
    
    NSString* path = attachment.fileSystemPath_modified;
    NSDictionary* documentFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    NSTimeInterval timeModified = [[documentFileAttributes fileModificationDate] timeIntervalSince1970];
    long long timeModifiedMilliseconds = (long long) trunc(timeModified * 1000.0f);
    
    
    NSString* md5 = [ZPZoteroAttachment md5ForFileAtPath:path];

    [attachment logFileRevisions];

    // The file is unmodified

    if([md5 isEqual:attachment.md5]){
        [ZPFileUploadManager finishedUploadingAttachment:attachment withVersionIdentifier:attachment.md5];
        [self cleanupAfterFinishingAttachment:attachment];
    }
    else{
        // Get upload authorization
        
        ASIHTTPRequest* request = [self _baseRequestForAttachment:attachment type:ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_AUTHORIZATION overWriteConflictingServerVersion:overwriteConflicting];
        
        if(request == NULL) return;
        
        
        
        NSString* postBodyString = [NSString stringWithFormat:@"md5=%@&filename=%@&filesize=%llu&mtime=%lli",
                                    md5,
                                    attachment.filename,
                                    [documentFileAttributes fileSize],
                                    timeModifiedMilliseconds ];
        
        
        NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] initWithCapacity:3];
        [userInfo setObject:attachment forKey:ZPKEY_ATTACHMENT];
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
        
        [_uploadQueue addOperation:request];
    }
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
        
    ZPZoteroAttachment* attachment = [request.userInfo objectForKey:ZPKEY_ATTACHMENT];
    
    if(request.tag == ZPFILECHANNEL_ZOTEROSTORAGE_DOWNLOAD){
        if(request.responseStatusCode == 200){
            DDLogInfo(@"Downloading %@ from Zotero succesfully finished",attachment.filename);

            NSString* versionIdentifier = [[[request responseHeaders] objectForKey:@"Etag"] stringByReplacingOccurrencesOfString:@"\"" withString:@""];

            [ZPFileDownloadManager finishedDownloadingAttachment:attachment toFileAtPath:[request downloadDestinationPath] withVersionIdentifier:versionIdentifier ];

            [self cleanupAfterFinishingAttachment:attachment];
        }
        else{

            NSError* error =[NSError errorWithDomain:@"zotero.org" code:request.responseStatusCode userInfo:NULL];
            DDLogError(@"Downloading %@ from Zotero server failed with error: %@",attachment.filename,request.responseStatusMessage);

            [self cleanupAfterFinishingAttachment:attachment];

            [ZPFileDownloadManager failedDownloadingAttachment:attachment withError:error fromURL:[request.url absoluteString]];
        }
    }
    else{
        
        // Additional troubleshooting info
        
        if([ZPPreferences debugFileUploadsAndDownloads]){
            NSString* dump =[self requestDumpAsString:request];
            DDLogInfo(@"%@",dump);
            DDLogInfo(@"Request user info:%@",request.userInfo);
        }

        if(request.tag == ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_AUTHORIZATION && request.responseStatusCode == 200){
            
            
            
            if([[request responseString] isEqualToString:@"{\"exists\":1}"]){
                //Finish uploading the attachment

                DDLogWarn(@"Upload of file %@ was declined by Zotero server because the file exists already on the Zotero server",attachment.filename);

                [ZPFileUploadManager finishedUploadingAttachment:attachment withVersionIdentifier:[request.userInfo objectForKey:@"md5"]];
                //TODO: Should there be some kind of notification that the file was not uploaded because it already exists?

                [self cleanupAfterFinishingAttachment:attachment];

            }
            else{
                
                DDLogInfo(@"Upload of file %@ was authorized by Zotero server",attachment.filename);

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

                    if(attachment.md5 != NULL){
                        [request addRequestHeader:@"If-Match" value:attachment.md5];
                    }
                    //This code should never run
                    
                    else{
                        DDLogError(@"Attachment %@ (%@) is missing version identification information. The local file will replace the server version without a version check.",attachment.key,attachment.filename);
                        [ZPServerConnection retrieveSingleItemWithKey:attachment.key fromLibraryWithID:attachment.libraryID completion:^(NSArray* attachmentList){
                            if(attachmentList.count == 1){
                                [self startUploadingAttachment:[attachmentList objectAtIndex:0] overWriteConflictingServerVersion:YES];
                            }
                            else{
                                DDLogError(@"Retrieving version information for attachment %@ (%@) during WebDAV upload resulted in %i results. The local file cannot be uploaded and will be purged.",attachment.filename, attachment.key,attachmentList.count);
                                [ZPFileCacheManager deleteModifiedFileForAttachment:attachment reason:@"Version information missing and server version does not exist"];
                            }
                        }];
                        [self cleanupAfterFinishingAttachment:attachment];
                        return;
                    }

                }
                else {
                    if(attachment.versionIdentifier_local == NULL){
                        [self presentConflictViewForAttachment:attachment reason:@"Local version identifier missing"];
                        [self cleanupAfterFinishingAttachment:attachment];
                        return;
                    }
                    [request addRequestHeader:@"If-Match" value:attachment.versionIdentifier_local];
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
                [_uploadQueue addOperation:uploadRequest];
            }
        }
        else if(request.tag == ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_FILE && request.responseStatusCode == 201){
            DDLogInfo(@"Uploading file %@ to Zotero server finished succesfully",attachment.filename);
                
            //Register upload
            ASIHTTPRequest* registerRequest = [self _baseRequestForAttachment:attachment type:ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_REGISTER overWriteConflictingServerVersion:[(NSNumber*)[request.userInfo objectForKey:@"overwriteConflicting"] boolValue]];
            if(request == NULL) return;

            registerRequest.userInfo = request.userInfo;
            [registerRequest setPostBody:[NSMutableData dataWithData:[[NSString stringWithFormat:@"upload=%@",[request.userInfo objectForKey:@"uploadKey"]] dataUsingEncoding:NSASCIIStringEncoding]]];
            [_uploadQueue addOperation:registerRequest];
                
        }
        else if(request.tag == ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_REGISTER && request.responseStatusCode == 204){
            
            DDLogInfo(@"New version of file %@ registered succesfully with Zotero server",attachment.filename);

            //All done
            [ZPFileUploadManager finishedUploadingAttachment:attachment withVersionIdentifier:[request.userInfo objectForKey:@"md5"]];
            [self cleanupAfterFinishingAttachment:attachment];
        }
        else if(request.responseStatusCode == 412){
            NSString* reason;
            switch (request.tag) {
                case ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_AUTHORIZATION:
                    reason = @"Zotero server reported version conflict when getting upload authorization";
                    break;
                case ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_FILE:
                    reason = @"Zotero server reported version conflict when uploading file";
                case ZPFILECHANNEL_ZOTEROSTORAGE_UPLOAD_REGISTER:
                    reason = @"Zotero server reported version conflict when registering an upload";
                    
                default:
                    break;
            }
            [ZPFileCacheManager deleteOriginalFileForAttachment:attachment reason:@"File is outdated (Zotero storage conflict)"];
            
            [ZPServerConnection retrieveSingleItemWithKey:attachment.key fromLibraryWithID:attachment.libraryID completion:^(NSArray* parsedResults) {
                if(parsedResults == NULL || [parsedResults count]==0){
                    [ZPFileUploadManager failedUploadingAttachment:attachment
                                                         withError:[NSError errorWithDomain:@"Zotero.org"
                                                                                       code:-1
                                                                                   userInfo:[NSDictionary dictionaryWithObject:@"Error retrieving metadata" forKey:NSLocalizedDescriptionKey]]
                                                             toURL:[request.url absoluteString]];
                    [self cleanupAfterFinishingAttachment:attachment];
                }
                else{
                    [self presentConflictViewForAttachment:attachment reason:@"Zotero server reported a version conflict when registering a file after WebDAV upload"];
                    
                }
            }];

            [self cleanupAfterFinishingAttachment:attachment];
            

        }
        else if(request.responseStatusCode == 413){
            
            DDLogWarn(@"Zotero server rejected upload of %@ because of insufficient storage space",attachment.filename);
            NSError* error =[NSError errorWithDomain:@"zotero.org"
                                                code:request.responseStatusCode
                                            userInfo:[NSDictionary dictionaryWithObject:@"Storage space exceeded"
                                                                                 forKey:NSLocalizedDescriptionKey]];
            
            if(! _alertVisible){
                [[[UIAlertView alloc] initWithTitle:@"Storage space exceeded"
                                            message:[NSString stringWithFormat:@"Uploading  of file (%@) failed because you have exceeded your storage space on the Zotero server",attachment.filename]
                                           delegate:self
                                  cancelButtonTitle:@"Cancel" otherButtonTitles:@"Check storage", @"Learn more", nil] show];
                _alertVisible = TRUE;
            }
            
            [ZPFileUploadManager failedUploadingAttachment:attachment withError:error toURL:[request.url absoluteString]];
            [self cleanupAfterFinishingAttachment:attachment];

        }

        else {
            NSError* error =[NSError errorWithDomain:@"zotero.org" code:request.responseStatusCode userInfo:NULL];
            DDLogError(@"Uploading file %@ to Zotero server failed with error: %@",attachment.filename,request.responseStatusMessage);
            
            [ZPFileUploadManager failedUploadingAttachment:attachment withError:error toURL:[request.url absoluteString]];
            [self cleanupAfterFinishingAttachment:attachment];

        }
    }
}

-(void) cancelUploadingAttachment:(ZPZoteroAttachment*)attachment{
    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    if(request != NULL){
        [request cancel];
    }
    [self cleanupAfterFinishingAttachment:attachment];
    
    [ZPFileUploadManager canceledUploadingAttachment:attachment ];
}

- (void)requestFailed:(ASIHTTPRequest *)request{
        
    NSError *error = [request error];
    ZPZoteroAttachment* attachment = [request.userInfo objectForKey:ZPKEY_ATTACHMENT];
    
    if(request.tag == ZPFILECHANNEL_ZOTEROSTORAGE_DOWNLOAD){
        DDLogError(@"Downloading file %@ from Zotero server failed with error: %@",attachment.filename, [error description]);
        [ZPFileDownloadManager failedDownloadingAttachment:attachment withError:error fromURL:[request.url absoluteString]];
    }
    else{
        DDLogError(@"Uploading failed %@ to Zotero server failed with error: %@",attachment.filename, [error description]);
        [ZPFileUploadManager failedUploadingAttachment:attachment withError:error toURL:[request.url absoluteString]];
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

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    //0: cancel
    
    if(buttonIndex==1){
        NSURL *url = [NSURL URLWithString:@"https://www.zotero.org/settings/storage"];
        
        if (![[UIApplication sharedApplication] openURL:url])
            
            DDLogError(@"%@%@",@"Failed to open url:",[url description]);
        
    }
    else if(buttonIndex==2){
        NSURL *url = [NSURL URLWithString:@"http://zotpad.uservoice.com/knowledgebase/articles/103784-which-file-storage-solution-should-i-use-"];
        
        if (![[UIApplication sharedApplication] openURL:url])
            
            DDLogError(@"%@%@",@"Failed to open url:",[url description]);
        
    }
    
    _alertVisible = false;
}

@end
