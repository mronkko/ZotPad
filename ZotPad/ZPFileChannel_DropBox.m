//
//  ZPFileChannel_DropBox.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPCore.h"

#import "ZPFileChannel_Dropbox.h"
#import <DropboxSDK/DropboxSDK.h>
#import "ZPPreferences.h"

#import "ZPServerConnection.h"

//Zipping and base64 encoding
#import "ZipArchive.h"
#import "QSStrings.h"


// https://www.dropbox.com/account#applications

@interface ZPDBRestClient : DBRestClient

@property (retain) ZPZoteroAttachment* attachment;
@property (retain) NSString* revision;

@end

@implementation ZPDBRestClient

@synthesize attachment,revision;

@end


@implementation ZPFileChannel_Dropbox

+(void)linkDroboxIfNeeded{
    if([[ZPPreferences instance] useDropbox]){
        if([DBSession sharedSession]==NULL){
            DDLogInfo(@"Starting Dropbox");
            DBSession* dbSession =
            [[DBSession alloc]
             initWithAppKey:@"or7xa2bxhzit1ws"
             appSecret:@"6azju842azhs5oz"
             root:kDBRootAppFolder];
            [DBSession setSharedSession:dbSession];
        }

        //Link with dropBox account if not already linked
        BOOL linked =[[DBSession sharedSession] isLinked];
        if (!linked) {
            DDLogInfo(@"Linking Dropbox");
            [[DBSession sharedSession] link];
        }
    }
}

-(id) init{ 
    
    [ZPFileChannel_Dropbox linkDroboxIfNeeded];

    self = [super init]; 
    
    progressViewsByRequest = [[NSMutableDictionary alloc] init];
    downloadCountsByRequest = [[NSMutableDictionary alloc] init];
        
    return self;
}

-(int) fileChannelType{
    return VERSION_SOURCE_DROPBOX;
}

-(NSObject*) keyForRequest:(NSObject*)request{
    return [NSNumber numberWithInt: request];
}

#pragma mark - Downloads

-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    //Link with dropBox account if not already linked
    [ZPFileChannel_Dropbox linkDroboxIfNeeded];
    
    //TODO: consider pooling these
    ZPDBRestClient* restClient = [[ZPDBRestClient alloc] initWithSession:[DBSession sharedSession]];
    restClient.attachment = attachment;
    restClient.delegate = self;
    
    [self linkAttachment:attachment withRequest:restClient];
    
    //If this is a website snapshot, we need to download all files
    if([attachment.linkMode intValue] == LINK_MODE_IMPORTED_URL && [attachment.contentType isEqualToString:@"text/html"]){
        //Get a list of files to be downloaded
        [restClient loadMetadata:[NSString stringWithFormat:@"/%@/",attachment.key]];
    }
    else{
        //Otherwise, load metadata for the file
        [restClient loadMetadata:[NSString stringWithFormat:@"/%@/%@",attachment.key,attachment.filename]];
    }
    
}
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{

    DBRestClient* restClient = [self requestWithAttachment:attachment];
    
    [restClient cancelFileLoad:[NSString stringWithFormat:@"/%@/%@",attachment.key,attachment.filename]];
    [self cleanupAfterFinishingAttachment:attachment];
}


-(void) useProgressView:(UIProgressView*) progressView forDownloadingAttachment:(ZPZoteroAttachment*)attachment{

    
    DBRestClient* restClient = [self requestWithAttachment:attachment];

    @synchronized(progressViewsByRequest){
        [progressViewsByRequest setObject:progressView forKey:[self keyForRequest:restClient]];
    }
}

#pragma mark - Uploads

-(void) startUploadingAttachment:(ZPZoteroAttachment*)attachment{

    //Link with dropBox account if not already linked

    [ZPFileChannel_Dropbox linkDroboxIfNeeded];
    
    //TODO: consider pooling these
    ZPDBRestClient* restClient = [[ZPDBRestClient alloc] initWithSession:[DBSession sharedSession]];
    restClient.attachment = attachment;
    restClient.delegate = self;
    
    [self linkAttachment:attachment withRequest:restClient];
    
    NSString* targetPath = [NSString stringWithFormat:@"/%@/",attachment.key];
    
    DDLogVerbose(@"Uploading file %@ to %@%@ (rev %@)",attachment.fileSystemPath_modified,targetPath,attachment.filename,attachment.versionIdentifier_local);
    
    [restClient uploadFile:attachment.filename toPath:targetPath withParentRev:attachment.versionIdentifier_local fromPath:attachment.fileSystemPath_modified];
   // [restClient uploadFile:attachment.filename toPath:@"/" withParentRev:NULL fromPath:attachment.fileSystemPath_modified];

}

-(void) useProgressView:(UIProgressView *)progressView forUploadingAttachment:(ZPZoteroAttachment *)attachment{
    DBRestClient* restClient = [self requestWithAttachment:attachment];
    
    @synchronized(progressViewsByRequest){
        [progressViewsByRequest setObject:progressView forKey:[self keyForRequest:restClient]];
    }

}

#pragma mark - Call backs

- (void)restClient:(ZPDBRestClient*)client loadedMetadata:(DBMetadata *)metadata {
        
    if (metadata.isDirectory) {
        ZPZoteroAttachment* attachment = client.attachment;
        DDLogVerbose(@"Folder '%@' contains:", metadata.path);
        NSString* basePath=[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
        [[NSFileManager defaultManager] createDirectoryAtPath:basePath withIntermediateDirectories:YES attributes:NULL error:NULL];
        for (DBMetadata *file in metadata.contents) {
            DDLogVerbose(@"\t%@", file.filename);
            NSString* tempFile = [basePath stringByAppendingPathComponent:file.filename];
            [client loadFile:[NSString stringWithFormat:@"/%@/%@",attachment.key,file.filename] intoPath:tempFile];
        }
        @synchronized(downloadCountsByRequest){
            [downloadCountsByRequest setObject:[NSNumber numberWithInt:[metadata.contents count]] forKey:[self keyForRequest:client]];
        }
    }
    else{
        //Set version of the file
        ZPZoteroAttachment* attachment = client.attachment;
        client.revision=metadata.rev;
        DDLogVerbose(@"Start downloading file /%@/%@ (rev %@)",attachment.key,attachment.filename,client.revision);
         NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
        [client loadFile:[NSString stringWithFormat:@"/%@/%@",attachment.key,attachment.filename] atRev:client.revision intoPath:tempFile];
    }
}

- (void)restClient:(ZPDBRestClient*) client loadMetadataFailedWithError:(NSError *)error {
    
    DDLogVerbose(@"Error loading metadata: %@", error);
    
    //If we are not linked, link
    if(error.code==401){
        DDLogInfo(@"Linking Dropbox");
        [[DBSession sharedSession] link];
    }
    
    ZPZoteroAttachment* attachment = client.attachment;
    [[ZPServerConnection instance] failedDownloadingAttachment:attachment withError:error usingFileChannel:self];    
    [self cleanupAfterFinishingAttachment:attachment];

}

- (void)restClient:(ZPDBRestClient*)client loadProgress:(CGFloat)progress forFile:(NSString*)destPath{

    ZPZoteroAttachment* attachment = client.attachment;
    if(!([attachment.linkMode intValue] == LINK_MODE_IMPORTED_URL && [attachment.contentType isEqualToString:@"text/html"])){ 
        @synchronized(progressViewsByRequest){
            UIProgressView* progressView = [progressViewsByRequest objectForKey:[self keyForRequest:client]];
            if(progressView!=NULL) [progressView setProgress:progress];
        }
    }
}
- (void)restClient:(ZPDBRestClient*)client loadedFile:(NSString*)localPath {
    
    ZPZoteroAttachment* attachment = client.attachment;
    
    //If this is a webpage snapshot
    if([attachment.linkMode intValue] == LINK_MODE_IMPORTED_URL && [attachment.contentType isEqualToString:@"text/html"]){
        
        //Update progress
        NSInteger total;
        @synchronized(downloadCountsByRequest){
            total = [(NSNumber*)[downloadCountsByRequest objectForKey:[self keyForRequest:client]] intValue];
        }
        @synchronized(progressViewsByRequest){
            UIProgressView* progressView = [progressViewsByRequest objectForKey:[self keyForRequest:client]];
            if(progressView!=NULL) [progressView setProgress:(total-[client requestCount]+1)/ (float) total];
        }

        if([client requestCount]==1){
            
            @synchronized(downloadCountsByRequest){
                [downloadCountsByRequest removeObjectForKey:[self keyForRequest:client]];
            }

            //All done


            NSString* zipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
            
            ZipArchive* zipArchive = [[ZipArchive alloc] init];

            [zipArchive CreateZipFile2:zipFilePath];
            
            //Encode the filenames
            
            NSString* tempPath = [localPath stringByDeletingLastPathComponent];
            
            NSArray* files = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:tempPath error:NULL];
            
            for (NSString* file in files){
                // The filenames end with %ZB64, which needs to be removed
                NSString* encodedFilename = [[QSStrings encodeBase64WithString:[file lastPathComponent]]stringByAppendingString:@"%ZB64"];
                
                DDLogVerbose(@"Encoded %@ as %@",file , encodedFilename);
                
                //Add to Zip with the new name
                [zipArchive addFileToZip:[tempPath stringByAppendingPathComponent:file] newname:encodedFilename];

                [[NSFileManager defaultManager] moveItemAtPath:file toPath:encodedFilename error:NULL];
                
            }

            //Create an archive
            
            [zipArchive CloseZipFile2];

            [[NSFileManager defaultManager] removeItemAtPath:tempPath error:NULL];
            
            localPath = zipFilePath;
            
            //Website snapshots do not use revision info in Dropbox
            
            [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:localPath withVersionIdentifier:NULL usingFileChannel:self];
            [self cleanupAfterFinishingAttachment:attachment];
        }
    }
    else{
        [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:localPath withVersionIdentifier:client.revision usingFileChannel:self];
        [self cleanupAfterFinishingAttachment:attachment];
    }
}

- (void)restClient:(ZPDBRestClient*)client loadFileFailedWithError:(NSError*)error {
    DDLogVerbose(@"There was an error downloading the file - %@", error);

    //If we are not linked, link
    if(error.code==401){
        DDLogInfo(@"Linking Dropbox");
        [[DBSession sharedSession] link];
    }

    ZPZoteroAttachment* attachment = client.attachment;
    [[ZPServerConnection instance] failedDownloadingAttachment:attachment withError:error usingFileChannel:self];
    [self cleanupAfterFinishingAttachment:attachment];

}

- (void)restClient:(ZPDBRestClient*)client uploadedFile:(NSString*)destPath from:(NSString*)srcPath 
          metadata:(DBMetadata*)metadata{
    
    ZPZoteroAttachment* attachment = client.attachment;
    
    //The local file now has a new version identifier
    attachment.versionIdentifier_local = metadata.rev;
    
    [[ZPServerConnection instance] finishedUploadingAttachment:attachment];
    [self cleanupAfterFinishingAttachment:attachment];

}
- (void)restClient:(DBRestClient*)client uploadProgress:(CGFloat)progress forFile:(NSString*)destPath from:(NSString*)srcPath{

    @synchronized(progressViewsByRequest){
        UIProgressView* progressView = [progressViewsByRequest objectForKey:[self keyForRequest:client]];
        if(progressView!=NULL) [progressView setProgress:progress];
    }

}
- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error{
    DDLogVerbose(@"There was an error uploading the file - %@", error);
    
    //If we are not linked, link
    if(error.code==401){
        DDLogInfo(@"Linking Dropbox");
        [[DBSession sharedSession] link];
    }
    
    ZPZoteroAttachment* attachment = [(ZPDBRestClient* )client attachment];
    [[ZPServerConnection instance] failedUploadingAttachment:attachment withError:error usingFileChannel:self];
    [self cleanupAfterFinishingAttachment:attachment];
}

#pragma mark - Utility methdods

-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment*)attachment{
    
    @synchronized(progressViewsByRequest){
        [progressViewsByRequest removeObjectForKey:[self keyForRequest:[self requestWithAttachment:attachment]]];
    }
    [super cleanupAfterFinishingAttachment:attachment];
}


@end
