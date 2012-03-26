//
//  ZPFileChannel_ZoteroStorage.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPFileChannel_ZoteroStorage.h"
#import "ZPPreferences.h"
#import "ASIHTTPRequest.h"
#import "ZPLogger.h"
#import "ZPServerConnection.h"

@implementation ZPFileChannel_ZoteroStorage


-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{

    
    if([attachment.existsOnZoteroServer boolValue]){
        
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
        
        urlString = [NSString stringWithFormat:@"%@/items/%@/file?key=%@",urlString, attachment.key, oauthkey];
        
        NSURL* url = [NSURL URLWithString:urlString];
        
        NSLog(@"Downloading attachment from %@",urlString);
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
        

        [self linkAttachment:attachment withRequest:request];
        
        //Easier to just always use accurate progress. There should not be a significant performance penalty
        request.showAccurateProgress=TRUE;

        NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
        [request setDownloadDestinationPath:tempFile];
        
        [request setDelegate:self];
        [request startAsynchronous];
    }
    //If the file does not exist on Zotero server, tell that we are finished
    else{
         [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:NULL usingFileChannel:self];
    }
   
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
    [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:[request downloadDestinationPath] usingFileChannel:self];

    [self cleanupAfterFinishingAttachment:attachment];
}

- (void)requestFailed:(ASIHTTPRequest *)request{
    NSError *error = [request error];
    NSLog(@"File download from Zotero server failed: %@",[error description]);
    ZPZoteroAttachment* attachment = [self attachmentWithRequest:request];
    [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:NULL usingFileChannel:self];
    
    [self cleanupAfterFinishingAttachment:attachment];

}



@end
