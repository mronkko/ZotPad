//
//  ZPFileChannel.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "ZPFileChannel.h"

//Implementations

#import "ZPFileChannel_Dropbox.h"
#import "ZPFileChannel_WebDAV.h"
#import "ZPFileChannel_ZoteroStorage.h"


#import "ZPUploadVersionConflictViewController.h"
#import "ZPFileImportViewController.h"
#import "ZPAppDelegate.h"

@implementation ZPFileChannel


static ZPFileChannel_WebDAV* _fileChannel_WebDAV;
static ZPFileChannel_Dropbox* _fileChannel_Dropbox;
static ZPFileChannel_ZoteroStorage* _fileChannel_Zotero;

+(void) initialize{
    _fileChannel_Dropbox = [[ZPFileChannel_Dropbox alloc] init];
    _fileChannel_WebDAV = [[ZPFileChannel_WebDAV alloc] init];
    _fileChannel_Zotero = [[ZPFileChannel_ZoteroStorage alloc] init];
}
+(ZPFileChannel*) fileChannelForAttachment:(ZPZoteroAttachment*) attachment{
    if([ZPPreferences useDropbox]){
        return _fileChannel_Dropbox;
    }
    else if(attachment.libraryID == LIBRARY_ID_MY_LIBRARY && [ZPPreferences useWebDAV]){
        return _fileChannel_WebDAV;
    }
    else {
        return _fileChannel_Zotero;
    }
}

+(NSInteger) activeUploads{
    if([ZPPreferences useDropbox]){
        return [ZPFileChannel_Dropbox activeUploads];
    }
    else if([ZPPreferences useWebDAV]){
        return [ZPFileChannel_ZoteroStorage activeUploads] + [ZPFileChannel_WebDAV activeUploads];
    }
    else{
        return [ZPFileChannel_ZoteroStorage activeUploads];
    }
}

+(NSInteger) activeDownloads{
    if([ZPPreferences useDropbox]){
        return [ZPFileChannel_Dropbox activeDownloads];
    }
    else if([ZPPreferences useWebDAV]){
        return [ZPFileChannel_ZoteroStorage activeDownloads] + [ZPFileChannel_WebDAV activeDownloads];
    }
    else{
        return [ZPFileChannel_ZoteroStorage activeDownloads];
    }
}

#pragma marK - Cleaning up progress views

+(void) removeProgressView:(UIProgressView*) progressView{
    [_fileChannel_Dropbox removeProgressView:progressView];
    [_fileChannel_WebDAV removeProgressView:progressView];
    [_fileChannel_Zotero removeProgressView:progressView];
}

-(id) init{
    self = [super init];
    _requestsByAttachment = [[NSMutableDictionary alloc] init];
    return self;
}

-(int) fileChannelType{
    return 0;
}
-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    //Does nothing by default
}
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    //Does nothing by default
}
-(void) useProgressView:(UIProgressView*) progressView forDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    //Does nothing by default
}

-(void) startUploadingAttachment:(ZPZoteroAttachment*)attachment overWriteConflictingServerVersion:(BOOL)overwriteConflicting{
    //Does nothing by default
}

-(void) cancelUploadingAttachment:(ZPZoteroAttachment*)attachment{
    //Does nothing by default
}

-(void) useProgressView:(UIProgressView*) progressView forUploadingAttachment:(ZPZoteroAttachment*)attachment{
    //Does nothing by default
}

-(void) removeProgressView:(UIProgressView*) progressView{
    //Does nothing by default
}

 
 
-(void) linkAttachment:(ZPZoteroAttachment*)attachment withRequest:(NSObject*)request{
    @synchronized(self){
        [_requestsByAttachment setObject:request forKey:attachment.key];
    }
}

-(id) requestWithAttachment:(ZPZoteroAttachment*)attachment{
    id ret;
    @synchronized(self){
        ret = [_requestsByAttachment objectForKey:attachment.key];
    }
    return ret;
}

-(NSArray*) allRequests{
    @synchronized(self){
        return [_requestsByAttachment allValues];
    }
}


-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment*)attachment{
    @synchronized(self){
        [_requestsByAttachment removeObjectForKey:attachment.key];
    }
}


-(void) presentConflictViewForAttachment:(ZPZoteroAttachment*) attachment reason:(NSString*) reason{
    
    DDLogWarn(@"Version conflict for file %@: %@", attachment.filenameBasedOnLinkMode, reason);
    
    //If we do not have the new version, start downloading it now
    
    
    if(![NSThread isMainThread]){
        dispatch_async(dispatch_get_main_queue(), ^{
            if(! [attachment fileExists_original]){
                [self startDownloadingAttachment:attachment];
            }
            [self presentConflictViewForAttachment:attachment reason:reason];
        });
    }
    else{
        [attachment logFileRevisions];
        [ZPUploadVersionConflictViewController presentInstanceModallyWithAttachment:attachment];
    }
}


-(NSString*) requestDumpAsString:(ASIHTTPRequest*)request{

    NSMutableString* dump = [[NSMutableString alloc] initWithFormat:@"Request: \n\n%@ %@ HTTP/1.1\n",request.requestMethod,request.url];
    
    for(NSString* key in request.requestHeaders){
        [dump appendFormat:@"%@: %@\n",key,[request.requestHeaders objectForKey:key]];
    }
    
    if(request.postBody && ! [request.requestMethod isEqualToString:@"PUT"]){
        [dump appendString:@"\n"];
        
        [dump appendString:[[NSString alloc] initWithData:request.postBody
                                                 encoding:NSUTF8StringEncoding]];
    }

    [dump appendFormat: @"\n\nResponse: \n\n%@\n",request.responseStatusMessage];

    for(NSString* key in request.responseHeaders){
        [dump appendFormat:@"%@: %@\n",key,[request.responseHeaders objectForKey:key]];
    }

    if(request.responseString){
        [dump appendString:@"\n"];
        [dump appendString:request.responseString];
    }
    return dump;
}

-(void) logVersionInformationForAttachment:(ZPZoteroAttachment *)attachment{

    //Do some extra logging if we have a prefence set for this
    if([ZPPreferences debugFileUploadsAndDownloads]){
        NSString* newMD5 = [ZPZoteroAttachment md5ForFileAtPath:attachment.fileSystemPath_modified];
        NSString* oldMD5 = NULL;
        if(attachment.fileExists_original){
            oldMD5 = [ZPZoteroAttachment md5ForFileAtPath:attachment.fileSystemPath_original];
        }
        DDLogInfo(@"Additional version information for file %@:",attachment.filenameBasedOnLinkMode);
        DDLogInfo(@"MD5 sum for old file:   %@", oldMD5);
        DDLogInfo(@"MD5 sum for new file:   %@", newMD5);
        DDLogInfo(@"Etag from current metadata: %@", attachment.etag);
        DDLogInfo(@"MD5 from current metadata: %@", attachment.md5);
        DDLogInfo(@"Local version identifier:  %@", attachment.versionIdentifier_local);
        DDLogInfo(@"Server version identifier:  %@", attachment.versionIdentifier_server);
    }

}

@end
