//
//  ZPFileChannel_DropBox.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "ZPFileChannel_Dropbox.h"
#import "DBRestClient.h"
#import "ZPPreferences.h"

#import "ZPServerConnection.h"

//Zipping and base64 encoding
#import "ZipArchive.h"


// https://www.dropbox.com/account#applications


const NSInteger ZPFILECHANNEL_DROPBOX_UPLOAD = 1;
const NSInteger ZPFILECHANNEL_DROPBOX_DOWNLOAD = 2;

#ifdef BETA

static const NSString* DROPBOX_KEY_FULL_ACCESS = @"w1nps3e4js2va7z";
static const NSString* DROPBOX_SECRET_FULL_ACCESS = @"vvk17pjqx0ngjs3";

static const NSString* DROPBOX_KEY = @"or7xa2bxhzit1ws";
static const NSString* DROPBOX_SECRET = @"6azju842azhs5oz";

#else

#import "ZPSecrets.h"

static const NSString* DROPBOX_KEY_FULL_ACCESS = @"6tpvh0msumv6plh";
static const NSString* DROPBOX_KEY = @"nn6res38igpo4ec";

#endif

@interface ZPDBRestClient : DBRestClient{
}

@property (retain) ZPZoteroAttachment* attachment;
@property (retain) NSString* revision;
@property BOOL overwriteConflicting;
@property NSInteger tag;

@end

@implementation ZPDBRestClient

@synthesize attachment,revision,overwriteConflicting,tag;

@end

@interface ZPFileChannel_Dropbox()

-(void) _restClient:(ZPDBRestClient*)client processError:(NSError *)error;
-(NSString*) _pathForAttachment:(ZPZoteroAttachment*)attachment;
-(NSString*) _URLForAttachment:(ZPZoteroAttachment*)attachment;

@end

@implementation ZPFileChannel_Dropbox


+(void) linkDroboxIfNeeded{
    if([[ZPPreferences instance] useDropbox]){
        if([DBSession sharedSession]==NULL){
            DDLogInfo(@"Starting Dropbox");
            
            if([[ZPPreferences instance] dropboxHasFullControl]){
                DBSession* dbSession =
                [[DBSession alloc]
                 initWithAppKey:DROPBOX_KEY_FULL_ACCESS
                 appSecret:DROPBOX_SECRET_FULL_ACCESS
                 root:kDBRootDropbox];
                [DBSession setSharedSession:dbSession];
                
            }
            else{
                DBSession* dbSession =
                [[DBSession alloc]
                 initWithAppKey:DROPBOX_KEY
                 appSecret:DROPBOX_SECRET
                 root:kDBRootAppFolder];
                [DBSession setSharedSession:dbSession];
            }
        }

        //Link with dropBox account if not already linked

        BOOL linked =[[DBSession sharedSession] isLinked];
        BOOL linking =[[DBSession sharedSession] isLinking];

        if (!linked && ! linking) {

            //Run on main thread
            
            DDLogInfo(@"Linking Dropbox");
            if([NSThread isMainThread]){

                //Unlink all so that we can relink
                [[DBSession sharedSession] unlinkAll];
                
                UIViewController* viewController = [UIApplication sharedApplication].delegate.window.rootViewController;
                while(viewController.presentedViewController) viewController = viewController.presentedViewController;
                
                //Start dismissing modal views
                while(viewController != [UIApplication sharedApplication].delegate.window.rootViewController){
                    UIViewController* parent = viewController.presentingViewController;
                    [viewController dismissModalViewControllerAnimated:NO];
                    viewController = parent;
                }
                [[DBSession sharedSession] linkFromController:viewController];
            }
            else {
                [[self class] performSelectorOnMainThread:@selector(linkDroboxIfNeeded) withObject:NULL waitUntilDone:YES];
            }
        }
    }
}

-(id) init{ 
    
    [ZPFileChannel_Dropbox linkDroboxIfNeeded];
    
    self = [super init]; 
    [DBSession sharedSession].delegate = self;
    
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

-(NSString*) _pathForAttachment:(ZPZoteroAttachment*)attachment{

    NSString* basePath;
    if([[ZPPreferences instance] dropboxPath] == NULL || [[[ZPPreferences instance] dropboxPath] isEqualToString:@""]){
        basePath = @"/storage";
    }
    else{
        basePath = [NSString stringWithFormat:@"/%@",[[ZPPreferences instance] dropboxPath]];
    }
    
    if([attachment.linkMode intValue] == LINK_MODE_IMPORTED_URL && [attachment.contentType isEqualToString:@"text/html"]){
        //Get a list of files to be downloaded. This does not respect custom file name template
        return [NSString stringWithFormat:@"%@/%@/",basePath, attachment.key];
    }
    else{
        //Otherwise, load metadata for the file usign the default patterns
        return [NSString stringWithFormat:@"%@/%@/%@",basePath, attachment.key,attachment.filename];
    }
}

-(NSString*) _URLForAttachment:(ZPZoteroAttachment*)attachment{
    
#ifdef BETA
    NSString* appFolder = @"ZotPad-beta";
#else
    NSString* appFolder = @"ZotPad";
#endif

    if([[ZPPreferences instance] dropboxHasFullControl]){
        return [@"https://www.dropbox.com/home" stringByAppendingString:[self _pathForAttachment:attachment]];
    }
    else{
        return [NSString stringWithFormat:@"https://www.dropbox.com/home/Apps/%@%@",appFolder,[self _pathForAttachment:attachment]];
    }
}

#pragma mark - Downloads

-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{

    DDLogInfo(@"Start downloading attachment %@ from Dropbox",attachment.filename);

    //Link with dropBox account if not already linked
    [ZPFileChannel_Dropbox linkDroboxIfNeeded];
    
    //TODO: consider pooling these
    ZPDBRestClient* restClient = [[ZPDBRestClient alloc] initWithSession:[DBSession sharedSession]];

    restClient.attachment = attachment;
    restClient.delegate = self;
    restClient.tag = ZPFILECHANNEL_DROPBOX_DOWNLOAD;
    
    [self linkAttachment:attachment withRequest:restClient];
    
    NSString* path = [self _pathForAttachment:attachment];
    //If this is a website snapshot, we need to download all files

    DDLogVerbose(@"Requesting metadata from Dropbox path %@",path);
    
    //Drobbox uses NSURLconnection internally, so it needs to be called in the main thread.
    [restClient performSelectorOnMainThread:@selector(loadMetadata:) withObject:[path precomposedStringWithCanonicalMapping] waitUntilDone:NO];
    
}
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{

    DBRestClient* restClient = [self requestWithAttachment:attachment];
    
    NSString* path = [self _pathForAttachment:attachment];
    [restClient cancelFileLoad:[path precomposedStringWithCanonicalMapping]];
    [self cleanupAfterFinishingAttachment:attachment];
}


-(void) useProgressView:(UIProgressView*) progressView forDownloadingAttachment:(ZPZoteroAttachment*)attachment{

    
    DBRestClient* restClient = [self requestWithAttachment:attachment];

    @synchronized(progressViewsByRequest){
        [progressViewsByRequest setObject:progressView forKey:[self keyForRequest:restClient]];
    }
}

#pragma mark - Uploads

-(void) startUploadingAttachment:(ZPZoteroAttachment*)attachment overWriteConflictingServerVersion:(BOOL)overwriteConflicting{

    DDLogInfo(@"Start uploading attachment %@ to Dropbox, overwrite: %i",attachment.filename,overwriteConflicting);

    //Link with dropBox account if not already linked

    [ZPFileChannel_Dropbox linkDroboxIfNeeded];
    
    //TODO: consider pooling these
    ZPDBRestClient* restClient = [[ZPDBRestClient alloc] initWithSession:[DBSession sharedSession]];

    
    restClient.attachment = attachment;
    restClient.delegate = self;
    restClient.overwriteConflicting = overwriteConflicting;
    restClient.tag = ZPFILECHANNEL_DROPBOX_UPLOAD;
    
    [self linkAttachment:attachment withRequest:restClient];
        
    NSString* path = [self _pathForAttachment:attachment];
    
    //Drobbox uses NSURLconnection internally, so it needs to be called in the main thread.
    [restClient performSelectorOnMainThread:@selector(loadMetadata:) withObject:[path precomposedStringWithCanonicalMapping] waitUntilDone:NO];

    
}

-(void) useProgressView:(UIProgressView *)progressView forUploadingAttachment:(ZPZoteroAttachment *)attachment{
    DBRestClient* restClient = [self requestWithAttachment:attachment];
    
    @synchronized(progressViewsByRequest){
        [progressViewsByRequest setObject:progressView forKey:[self keyForRequest:restClient]];
    }

}

#pragma mark - Call backs

- (void)restClient:(ZPDBRestClient*)client loadedMetadata:(DBMetadata *)metadata {
    
    DDLogVerbose(@"Dropbox returned metadata");
    
    ZPZoteroAttachment* attachment = client.attachment;
    
    if(client.tag == ZPFILECHANNEL_DROPBOX_DOWNLOAD){
        if (metadata.isDirectory) {
           
            DDLogVerbose(@"Folder '%@' contains:", metadata.path);
            NSString* basePath=[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
            [[NSFileManager defaultManager] createDirectoryAtPath:basePath withIntermediateDirectories:YES attributes:NULL error:NULL];

            NSString* path = [self _pathForAttachment:attachment];
            for (DBMetadata *file in metadata.contents) {
                DDLogVerbose(@"\t%@", file.filename);
                NSString* tempFile = [basePath stringByAppendingPathComponent:file.filename];
                [client loadFile:[[path stringByAppendingPathComponent:file.filename] precomposedStringWithCanonicalMapping] intoPath:tempFile];
            }
            @synchronized(downloadCountsByRequest){
                [downloadCountsByRequest setObject:[NSNumber numberWithInt:[metadata.contents count]] forKey:[self keyForRequest:client]];
            }
        }
        else{
            //Set version of the file
            client.revision=metadata.rev;
            DDLogVerbose(@"Start downloading file /%@/%@ (rev %@)",attachment.key,attachment.filename,client.revision);
            NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
            NSString* path = [self _pathForAttachment:attachment];
            [client loadFile:[path precomposedStringWithCanonicalMapping] atRev:client.revision intoPath:tempFile];
        }
    }
    // Uploading
    else if(client.tag == ZPFILECHANNEL_DROPBOX_UPLOAD){
        NSString* path = [self _pathForAttachment:attachment];
        NSString* targetPath = [path stringByDeletingLastPathComponent];        
        if(client.overwriteConflicting){
            [client uploadFile:[[path lastPathComponent] precomposedStringWithCanonicalMapping] toPath:[targetPath precomposedStringWithCanonicalMapping] withParentRev:metadata.rev fromPath:attachment.fileSystemPath_modified];
        }
        else if(! [attachment.versionIdentifier_local isEqualToString:metadata.rev]){
            [self presentConflictViewForAttachment:attachment];
        }
        else{
            [client uploadFile:[[path lastPathComponent] precomposedStringWithCanonicalMapping] toPath:[targetPath precomposedStringWithCanonicalMapping] withParentRev:attachment.versionIdentifier_local fromPath:attachment.fileSystemPath_modified];
        }
    }
}


- (void)restClient:(ZPDBRestClient*) client loadMetadataFailedWithError:(NSError *)error {
    
    DDLogVerbose(@"Error loading metadata: %@", error);
    
    [self _restClient:client processError:error];
    
    ZPZoteroAttachment* attachment = client.attachment;
    [[ZPServerConnection instance] failedDownloadingAttachment:attachment withError:error usingFileChannel:self fromURL:[self _URLForAttachment:attachment]];    
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
    
    DDLogVerbose(@"Dropbox returned file");

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
                NSString* encodedFilename = [ZPZoteroAttachment zoteroBase64Encode:[file lastPathComponent]];                
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
            
            [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:localPath withVersionIdentifier:@"" usingFileChannel:self];
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

    [self _restClient:client processError:error];
    
    ZPZoteroAttachment* attachment = client.attachment;
    [[ZPServerConnection instance] failedDownloadingAttachment:attachment withError:error usingFileChannel:self fromURL:[self _URLForAttachment:attachment]];
    [self cleanupAfterFinishingAttachment:attachment];

}

- (void)restClient:(ZPDBRestClient*)client uploadedFile:(NSString*)destPath from:(NSString*)srcPath 
          metadata:(DBMetadata*)metadata{
    
    DDLogVerbose(@"Dropbox uploaded file");

    ZPZoteroAttachment* attachment = client.attachment;
    
    [[ZPServerConnection instance] finishedUploadingAttachment:attachment withVersionIdentifier:metadata.rev];
    [self cleanupAfterFinishingAttachment:attachment];

}
- (void)restClient:(ZPDBRestClient*)client uploadProgress:(CGFloat)progress forFile:(NSString*)destPath from:(NSString*)srcPath{

    @synchronized(progressViewsByRequest){
        UIProgressView* progressView = [progressViewsByRequest objectForKey:[self keyForRequest:client]];
        if(progressView!=NULL) [progressView setProgress:progress];
    }

}
- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error{
    DDLogVerbose(@"There was an error uploading the file - %@", error);
    
    [self _restClient:client processError:error];
    
    ZPZoteroAttachment* attachment = [(ZPDBRestClient* )client attachment];
    [[ZPServerConnection instance] failedUploadingAttachment:attachment withError:error usingFileChannel:self toURL:[self _URLForAttachment:attachment]];
    [self cleanupAfterFinishingAttachment:attachment];
}


-(void) removeProgressView:(UIProgressView*) progressView{
    
    @synchronized(progressViewsByRequest){
        for (NSObject* key in progressViewsByRequest){
            if([progressViewsByRequest objectForKey:key] == progressView){
                [progressViewsByRequest removeObjectForKey:key];
            }
        }
    }
}

#pragma DBSession delegate

- (void)sessionDidReceiveAuthorizationFailure:(DBSession *)session userId:(NSString *)userId{
    DDLogError(@"Authorization failure with Dropbox for user ID %@. Will unlink and attemp to relink later.",userId);
    if(userId != NULL){
        [[DBSession sharedSession] unlinkAll];
    }
}

#pragma mark - Utility methdods

-(void) _restClient:(ZPDBRestClient*) client processError:(NSError *)error{
    //If we are not linked, link
    if(error.code==401){
        DDLogInfo(@"Linking Dropbox");
        [ZPFileChannel_Dropbox linkDroboxIfNeeded];
    }

}

-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment*)attachment{
    
    @synchronized(progressViewsByRequest){
        [progressViewsByRequest removeObjectForKey:[self keyForRequest:[self requestWithAttachment:attachment]]];
    }

    [super cleanupAfterFinishingAttachment:attachment];
}


@end
