//
//  ZPFileChannel_DropBox.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPFileChannel_Dropbox.h"
#import <DropboxSDK/DropboxSDK.h>
#import "ZPPreferences.h"
#import "ASIHTTPRequest.h"
#import "ZPLogger.h"
#import "ZPServerConnection.h"

//Zipping and base64 encoding
#import "ZipArchive.h"
#import "QSStrings.h"

@implementation ZPFileChannel_Dropbox

-(id) init{
    
    self = [super init]; 
    DBSession* dbSession =
    [[DBSession alloc]
     initWithAppKey:@"or7xa2bxhzit1ws"
     appSecret:@"6azju842azhs5oz"
     root:kDBRootAppFolder];
    [DBSession setSharedSession:dbSession];
    
    progressViewsByRequest = [[NSMutableDictionary alloc] init];
    downloadCountsByRequest = [[NSMutableDictionary alloc] init];

    return self;
}

-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    if([[ZPPreferences instance] useDropbox]){
        
        //Link with dropBox account if not already linked
        
        if (![[DBSession sharedSession] isLinked]) {
            [[DBSession sharedSession] link];
        }

        //TODO: consider pooling these
        DBRestClient* restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        restClient.delegate = self;
        
        NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
        
        [self linkAttachment:attachment withRequest:restClient];

        //If this is a website snapshot, we need to download all files
        if([attachment.linkMode intValue] == LINK_MODE_IMPORTED_URL && [attachment.contentType isEqualToString:@"text/html"]){
            //Get a list of files to be downloaded
            [restClient loadMetadata:[NSString stringWithFormat:@"/%@/",attachment.key]];
        }
        else{
            //Otherwise, download just one file
            [restClient loadFile:[NSString stringWithFormat:@"/%@/%@",attachment.key,attachment.filename] intoPath:tempFile];
        }
    }
    // If Dropbox is not in use, just notify that we are done
    else [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:NULL usingFileChannel:self];

}
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{

    DBRestClient* restClient = [self requestWithAttachment:attachment];
    
    [restClient cancelFileLoad:[NSString stringWithFormat:@"/%@/%@",attachment.key,attachment.filename]];
    [self cleanupAfterFinishingAttachment:attachment];
}
-(void) useProgressView:(UIProgressView*) progressView forAttachment:(ZPZoteroAttachment*)attachment{

    
    DBRestClient* restClient = [self requestWithAttachment:attachment];

    @synchronized(progressViewsByRequest){
        [progressViewsByRequest setObject:progressView forKey:[self keyForRequest:restClient]];
    }
}
- (void)restClient:(DBRestClient *)client loadedMetadata:(DBMetadata *)metadata {
    if (metadata.isDirectory) {
        ZPZoteroAttachment* attachment = [self attachmentWithRequest:client];
        NSLog(@"Folder '%@' contains:", metadata.path);
        NSString* basePath=[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
        [[NSFileManager defaultManager] createDirectoryAtPath:basePath withIntermediateDirectories:YES attributes:NULL error:NULL];
        for (DBMetadata *file in metadata.contents) {
            NSLog(@"\t%@", file.filename);
            NSString* tempFile = [basePath stringByAppendingPathComponent:file.filename];
            [client loadFile:[NSString stringWithFormat:@"/%@/%@",attachment.key,file.filename] intoPath:tempFile];
        }
        @synchronized(downloadCountsByRequest){
            [downloadCountsByRequest setObject:[NSNumber numberWithInt:[metadata.contents count]] forKey:[self keyForRequest:client]];
        }
    }
}

- (void)restClient:(DBRestClient *)client loadMetadataFailedWithError:(NSError *)error {
    
    NSLog(@"Error loading metadata: %@", error);
    
    ZPZoteroAttachment* attachment = [self attachmentWithRequest:client];
    [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:NULL usingFileChannel:self];
    
    [self cleanupAfterFinishingAttachment:attachment];

}

- (void)restClient:(DBRestClient*)client loadProgress:(CGFloat)progress forFile:(NSString*)destPath{

    ZPZoteroAttachment* attachment = [self attachmentWithRequest:client];
    if(!([attachment.linkMode intValue] == LINK_MODE_IMPORTED_URL && [attachment.contentType isEqualToString:@"text/html"])){ 
        @synchronized(progressViewsByRequest){
            UIProgressView* progressView = [progressViewsByRequest objectForKey:[self keyForRequest:client]];
            if(progressView!=NULL) [progressView setProgress:progress];
        }
    }
}
- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)localPath {
    
    ZPZoteroAttachment* attachment = [self attachmentWithRequest:client];
    
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
                
                NSLog(@"Encoded %@ as %@",file , encodedFilename);
                
                //Add to Zip with the new name
                [zipArchive addFileToZip:[tempPath stringByAppendingPathComponent:file] newname:encodedFilename];

                [[NSFileManager defaultManager] moveItemAtPath:file toPath:encodedFilename error:NULL];
                
            }

            //Create an archive
            
            [zipArchive CloseZipFile2];

            [[NSFileManager defaultManager] removeItemAtPath:tempPath error:NULL];
            
            localPath = zipFilePath;

            [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:localPath usingFileChannel:self];
            [self cleanupAfterFinishingAttachment:attachment];
        }
    }
    else{
        [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:localPath usingFileChannel:self];
        [self cleanupAfterFinishingAttachment:attachment];
    }
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error {
    NSLog(@"There was an error loading the file - %@", error);

    ZPZoteroAttachment* attachment = [self attachmentWithRequest:client];
    [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:NULL usingFileChannel:self];

    [self cleanupAfterFinishingAttachment:attachment];

}

-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment*)attachment{
    
    @synchronized(progressViewsByRequest){
        [progressViewsByRequest removeObjectForKey:[self keyForRequest:[self requestWithAttachment:attachment]]];
    }
    [super cleanupAfterFinishingAttachment:attachment];
}

@end
