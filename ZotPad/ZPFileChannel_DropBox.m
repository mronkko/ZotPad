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
#import "DBSession.h"
#import "DBSession+iOS.h"

#import "ZPLocalization.h"
#import "ZPSecrets.h"



//Zipping and base64 encoding
#import "ZipArchive.h"

@interface ZPDBSession : DBSession {
    BOOL _ZPisLinking;
}
@property (readonly) BOOL isLinking;
@end

@implementation ZPDBSession

@synthesize isLinking = _ZPisLinking;

- (void)linkFromController:(UIViewController *)rootController {
    _ZPisLinking = TRUE;
    [super linkFromController:rootController];
}

- (BOOL)handleOpenURL:(NSURL *)url {
    BOOL ret = [super handleOpenURL:url];
    _ZPisLinking = FALSE;
    return ret;
}


@end

@interface ZPFileChannel_Dropbox()

-(void) _restClient:(DBRestClient*)client processError:(NSError *)error;
-(NSString*) _pathForAttachment:(ZPZoteroAttachment*)attachment;
-(NSString*) _URLForAttachment:(ZPZoteroAttachment*)attachment;
-(NSString*) _filenameOrPathForAttachment:(ZPZoteroAttachment*)attachment withPattern:(NSString*)pattern;

-(ZPZoteroAttachment*) _attachmentForDBMetadata:(DBMetadata*)metadata;
-(ZPZoteroAttachment*) _attachmentForDBError:(NSError *)error;
-(ZPZoteroAttachment*) _attachmentForLocalDestinationPath:(NSString*)destPath;
-(ZPZoteroAttachment*) _attachmentForRemotePath:(NSString*)path;

@end

@implementation ZPFileChannel_Dropbox

static DBRestClient* _uploadClientThatOverwritesServerVersion;
static DBRestClient* _uploadClientThatCreatesConflict;
static DBRestClient* _downloadClient;

+(NSInteger) activeDownloads{
    return [_downloadClient requestCount];
}
+(NSInteger) activeUploads{
    return [_uploadClientThatOverwritesServerVersion requestCount] +
        [_uploadClientThatCreatesConflict requestCount];
}


+(void) linkDropboxIfNeeded{
    if([ZPPreferences useDropbox]){
        
        if([ZPDBSession sharedSession]==NULL){
            DDLogInfo(@"Starting Dropbox");
            
            if([ZPPreferences dropboxHasFullControl]){
                
                if(DROPBOX_KEY_FULL_ACCESS == nil || DROPBOX_SECRET_FULL_ACCESS == nil) [NSException raise:@"Missing credentials exception" format:@"Authentication key or secret for Dropbox (full access) is missing. Please see the file ZotPad/Secrets.h for details"];
                
                
                ZPDBSession* dbSession =
                [[ZPDBSession alloc]
                 initWithAppKey:(NSString*)DROPBOX_KEY_FULL_ACCESS
                 appSecret:(NSString*)DROPBOX_SECRET_FULL_ACCESS
                 root:kDBRootDropbox];
                [ZPDBSession setSharedSession:dbSession];
                
            }
            else{
                
                if(DROPBOX_KEY == nil || DROPBOX_SECRET == nil) [NSException raise:@"Missing credentials exception" format:@"Authentication key or secret for Dropbox is missing. Please see the file ZotPad/Secrets.h for details"];
                
                ZPDBSession* dbSession =
                [[ZPDBSession alloc]
                 initWithAppKey:(NSString*)DROPBOX_KEY
                 appSecret:(NSString*)DROPBOX_SECRET
                 root:kDBRootAppFolder];
                [ZPDBSession setSharedSession:dbSession];
            }
            
        }
        
        //Link with dropBox account if not already linked
        
        BOOL linked =[[ZPDBSession sharedSession] isLinked];
        BOOL linking =[(ZPDBSession*) [ZPDBSession sharedSession] isLinking];
        
        if (!linked && ! linking) {
            
            //Run on main thread
            
            DDLogInfo(@"Linking Dropbox");
            if([NSThread isMainThread]){
                
                DDLogInfo(@"Unlinking existing Dropbox sessions");
                
                //Unlink all so that we can relink
                [[ZPDBSession sharedSession] unlinkAll];
                
                UIViewController* viewController = [UIApplication sharedApplication].delegate.window.rootViewController;
                while(viewController.presentedViewController) viewController = viewController.presentedViewController;
                
                //Start dismissing modal views
                while(viewController != [UIApplication sharedApplication].delegate.window.rootViewController){
                    UIViewController* parent = viewController.presentingViewController;
                    [viewController dismissModalViewControllerAnimated:NO];
                    viewController = parent;
                }
                
                DDLogInfo(@"Presenting Dropbox linking dialog");
                
                [[ZPDBSession sharedSession] linkFromController:viewController];
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [ZPFileChannel_Dropbox linkDropboxIfNeeded];
                });
            }
        }
    }
}

-(id) init{
    
    [ZPFileChannel_Dropbox linkDropboxIfNeeded];
    
    self = [super init];
    [ZPDBSession sharedSession].delegate = self;
    
    _uploadClientThatOverwritesServerVersion = [[DBRestClient alloc] initWithSession:[ZPDBSession sharedSession]];
    _uploadClientThatOverwritesServerVersion.delegate = self;
    _uploadClientThatCreatesConflict = [[DBRestClient alloc] initWithSession:[ZPDBSession sharedSession]];
    _uploadClientThatCreatesConflict.delegate = self;
    _downloadClient = [[DBRestClient alloc] initWithSession:[ZPDBSession sharedSession]];
    _downloadClient.delegate = self;
    
    downloadProgressViewsByAttachment = [[NSMutableDictionary alloc] init];
    downloadCountsByAttachment = [[NSMutableDictionary alloc] init];
    remoteVersions = [[NSMutableDictionary alloc] init];
    return self;
}

-(int) fileChannelType{
    return VERSION_SOURCE_DROPBOX;
}

-(NSObject*) keyForRequest:(NSObject*)request{
    return [NSNumber numberWithInt: (NSInteger) request];
}


-(NSString*) _filenameOrPathForAttachment:(ZPZoteroAttachment*)attachment withPattern:(NSString*)pattern{
    
    NSString* creatorString;
    NSArray* creators;
    NSString* suffix;
    
    ZPZoteroItem* parent = [ZPZoteroItem itemWithKey:attachment.parentKey];
    
    NSInteger numAuthors = [ZPPreferences maxNumberOfAuthorsInDropboxFilenames];
    
    if(numAuthors >0 &&  [parent.creators count] > numAuthors){
        creators = [NSArray arrayWithObject:[parent.creators objectAtIndex:0]];
        suffix = [ZPPreferences authorSuffixInDropboxFilenames];
    }
    else{
        creators = parent.creators;
        suffix = @"";
    }
    
    NSSet* creatorTypes;
    
    if([parent.itemType isEqualToString:@"book"]){
        creatorTypes = [NSSet setWithObjects:@"author", @"editor", nil];
    }
    else if([parent.itemType isEqualToString:@"patent"]){
        creatorTypes = [NSSet setWithObject:@"inventor"];
    }
    else if([parent.itemType isEqualToString:@"computerProgram"]){
        creatorTypes = [NSSet setWithObject:@"programmer"];
    }
    else if([parent.itemType isEqualToString:@"presentation"]){
        creatorTypes = [NSSet setWithObject:@"presenter"];
    }
    else{
        creatorTypes = [NSSet setWithObject:@"author"];
    }
    
    NSMutableArray* creatorNames = [[NSMutableArray alloc] initWithCapacity:[creators count]];
    
    for(NSDictionary* creator in creators){
        if([creatorTypes containsObject:[creator objectForKey:@"creatorType"]]){
            NSObject* lastName = [creator objectForKey:@"lastName"];
            NSObject* name = [creator objectForKey:@"name"];
            if(lastName != nil){
                [creatorNames addObject:lastName];
            }
            else if(name != nil){
                [creatorNames addObject:name];
            }
        }
    }
    
    creatorString = [[creatorNames componentsJoinedByString:@"_"] stringByAppendingString:suffix];
    
    NSString* title;
    
    if([ZPPreferences truncateTitlesInDropboxFilenames]){
        title = [[parent.title componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":.?"]] objectAtIndex:0];
    }
    else{
        title= parent.title;
    }
    
    NSInteger nameLength = [ZPPreferences maxTitleLengthInDropboxFilenames];
    if(nameLength >0 && [title length] > nameLength){
        
        NSString* newTitle = [title substringToIndex:nameLength];

        // This implements the truncate_smart option of ZotFile. This is a hidden preference in Zotfile, and probably always on.
        // Apply if the title contains spaces and if the first truncated character matches a regexp
        
        BOOL hasSpaces = [newTitle rangeOfString:@" "].location != NSNotFound;
        
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[a-zA-Z0-9]"
                                                                               options:0
                                                                                 error:nil];

        BOOL firstTruncatedCharacterIsAplhaNumeric = [regex numberOfMatchesInString:title
                                                                options:0
                                                                  range:NSMakeRange(nameLength, 1)] > 0;
        
        if(hasSpaces && firstTruncatedCharacterIsAplhaNumeric){
            while(! [[newTitle substringWithRange:NSMakeRange([newTitle length]-1, 1)] isEqualToString:@" "])
                newTitle = [newTitle substringToIndex:[newTitle length]-1];

            //Remove the last space
        
            newTitle = [newTitle substringToIndex:[newTitle length]-1];
        }
        
        title = newTitle;
    }
    
    NSString* publicationTitle = [parent.fields objectForKey:@"publicationTitle"];
    NSString* publisher = [parent.fields objectForKey:@"publisher"];
    NSString* journalAbbreviation = [parent.fields objectForKey:@"journalAbbreviation"];
    NSString* volume = [parent.fields objectForKey:@"volume"];
    NSString* issue = [parent.fields objectForKey:@"issue"];
    NSString* patentNumber = [parent.fields objectForKey:@"patentNumber"];
    NSString* assignee = [parent.fields objectForKey:@"assignee"];
    NSString* issued = [parent.fields objectForKey:@"issueDate"];
    
    NSInteger year;
    
    if([parent.itemType isEqualToString:@"patent"]){
        if(issued != NULL) year = [[issued substringToIndex:4] integerValue];
    }
    else{
        year = parent.year;
    }
    
    NSArray* nameFragments = [pattern componentsSeparatedByString:@"%"];
    NSMutableString* customName = [NSMutableString stringWithString:[nameFragments objectAtIndex:0]];
    
    
    for (NSInteger i = 1; i < [nameFragments count]; i++) {
        
        NSString* nameFragment = [nameFragments objectAtIndex:i];
        
        
        switch ([nameFragment characterAtIndex:0]) {
                
                // %a - last names of authors (not editors etc) or inventors.
            case 'a':
                [customName appendString:creatorString];
                break;
                
                // %A - first letter of author (useful for subfolders)
            case 'A':
                [customName appendString:[[creatorString substringToIndex:1] uppercaseString]];
                break;
                
                // %y - year (extracted from Date field)
            case 'y':
                if(year != 0) [customName appendString:[[NSNumber numberWithInt:year] stringValue]];
                break;
                
                // %t - title. Usually truncated after : . ? The maximal length of the remaining part of the title can be changed.
            case 't':
                [customName appendString:title];
                break;
                
                // %T - item type (localized)
            case 'T':
                [customName appendString:[ZPLocalization getLocalizationStringWithKey:parent.itemType type:@"itemType"]];
                break;
                
                // %j - name of the journal
            case 'j':
                if(publicationTitle != NULL) [customName appendString:publicationTitle];
                break;
                
                // %p - name of the publisher
            case 'p':
                if(publisher != NULL) [customName appendString:publisher];
                break;
                
                // %w - name of the journal or publisher
            case 'w':
                if(publicationTitle != NULL) [customName appendString:publicationTitle];
                else if(publisher != NULL) [customName appendString:publisher];
                break;
                
                // %s - journal abbreviation
            case 's':
                if(journalAbbreviation != NULL) [customName appendString:journalAbbreviation];
                break;
                
                // %v - journal volume
            case 'v':
                if(volume != NULL) [customName appendString:volume];
                break;
                
                // %e - journal issue
            case 'e':
                if(issue != NULL) [customName appendString:issue];
                break;
                
                
                // %n - patent number (patent items only)
            case 'n':
                if(patentNumber != NULL) [customName appendString:patentNumber];
                break;
                
                // %i - assignee (patent items only)
            case 'i':
                if(assignee != NULL) [customName appendString:assignee];
                break;
                
                // %u - issue date (patent items only)
            case 'u':
                if(issued != NULL) [customName appendString:[issued substringToIndex:4]] ;
                break;
                
                //Specific to ZotPad
                /*
                 case 'k':
                 [customName appendString:attachment.key] ;
                 break;
                 
                 case 'f':
                 [customName appendString:attachment.filename] ;
                 break;
                 */
                
            default:
                DDLogError(@"Invalid dropbox file pattern specifier %c in pattern %@",[nameFragment characterAtIndex:0],pattern);
                break;
        }
        
        //Add rest of the fragment
        if([nameFragment length]>1){
            [customName appendString:[nameFragment substringFromIndex:1]];
        }
        
    }
    return customName;
}

-(NSString*) _pathForAttachment:(ZPZoteroAttachment*)attachment{
    
    
#ifdef BETA
    NSString* appFolder = @"ZotPad-beta";
#else
    NSString* appFolder = @"ZotPad";
#endif
    
    NSString* basePath = [ZPPreferences dropboxPath];
    
    if(![ZPPreferences dropboxHasFullControl]){
        if([ZPPreferences dropboxPath] != NULL && ! [[ZPPreferences dropboxPath] hasPrefix:[@"Apps/" stringByAppendingString:appFolder]]){
            
            NSString* defaultPath = [NSString stringWithFormat:@"Apps/%@/storage",appFolder];
            
            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Dropbox configuration error"
                                                                message:[NSString stringWithFormat:@"Your Dropbox settings allow ZotPad to acces only app folder located at 'Apps/%@', but the current path to our Dropbox files pointed to '%@'. Path to Dropbox files has been reset to default value 'Apps/%@/storage'",appFolder,[ZPPreferences dropboxPath], appFolder]
                                                               delegate:NULL cancelButtonTitle:@"OK" otherButtonTitles: nil];
            
            [alertView performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
            
            [ZPPreferences setDropboxPath:defaultPath];
            basePath = defaultPath;
        }
        
        basePath = [basePath stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"Apps/%@",appFolder] withString:@""] ;
    }
    
    
    if(! [basePath isEqualToString:@""]){
        basePath = [basePath stringByAppendingString:@"/"];
    }
    
    if([ZPPreferences useCustomFilenamesWithDropbox]){
        
        ZPZoteroItem* parent = [ZPZoteroItem itemWithKey:attachment.parentKey];
        
        NSString* pattern;
        
        if([parent.itemType isEqualToString:@"patent"]){
            pattern = [ZPPreferences customPatentFilenamePatternForDropbox];
        }
        else{
            pattern = [ZPPreferences customFilenamePatternForDropbox];
        }
        
        NSMutableString* customName = [NSMutableString stringWithString:[self _filenameOrPathForAttachment:attachment withPattern:pattern]];
        
        // Remove invalid characters
        
        [customName replaceOccurrencesOfString:@"/" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [customName length])];
        [customName replaceOccurrencesOfString:@"\\" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [customName length])];
        [customName replaceOccurrencesOfString:@"?" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [customName length])];
        [customName replaceOccurrencesOfString:@"*" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [customName length])];
        [customName replaceOccurrencesOfString:@":" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [customName length])];
        [customName replaceOccurrencesOfString:@"|" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [customName length])];
        [customName replaceOccurrencesOfString:@"\"" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [customName length])];
        [customName replaceOccurrencesOfString:@"<" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [customName length])];
        [customName replaceOccurrencesOfString:@">" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [customName length])];
        [customName replaceOccurrencesOfString:@"." withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [customName length])];
        
        //Replace white space
        
        NSArray* words = [customName componentsSeparatedByCharactersInSet :[NSCharacterSet whitespaceCharacterSet]];
        customName = [NSMutableString stringWithString:[words componentsJoinedByString:@" "]];
        
        
        if([ZPPreferences replaceBlanksInDropboxFilenames]){
            [customName replaceOccurrencesOfString:@" " withString:@"_" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [customName length])];
        }
        if([ZPPreferences removeDiacriticsInDropboxFilenames]){
            
            NSData *asciiEncoded = [customName dataUsingEncoding:NSASCIIStringEncoding
                                            allowLossyConversion:YES];
            
            // take the data object and recreate a string using the lossy conversion
            customName = [[NSMutableString alloc] initWithData:asciiEncoded
                                                      encoding:NSASCIIStringEncoding];
        }
        
        NSString* fileTypeSuffix = [attachment.filenameBasedOnLinkMode pathExtension];
        
        if(![fileTypeSuffix isEqualToString:@""]){
            [customName appendFormat:@".%@",[fileTypeSuffix lowercaseString]];
        }
        
        NSString* folderPattern = [ZPPreferences customSubfolderPatternForDropbox];
        if(![folderPattern isEqualToString:@""]){
            folderPattern = [folderPattern stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
            folderPattern = [folderPattern stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" /"]];
            folderPattern = [NSString stringWithFormat:@"/%@/", folderPattern];
            NSString* folder = [self _filenameOrPathForAttachment:attachment withPattern:folderPattern];
            folder = [folder stringByReplacingOccurrencesOfString:@"//" withString:@"/undefined/"];
            
            customName = (NSMutableString*) [[folder stringByAppendingString:customName] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
        }
        return [NSString stringWithFormat:@"/%@%@",basePath,customName];
        
    }
    else{
        if(attachment.linkMode == LINK_MODE_IMPORTED_URL && (
                                                             [attachment.contentType isEqualToString:@"text/html"] ||
                                                             [attachment.contentType isEqualToString:@"application/xhtml+xml"])){
            //Get a list of files to be downloaded. This does not respect custom file name template
            return [NSString stringWithFormat:@"/%@%@/",basePath, attachment.key];
        }
        else{
            //Otherwise, load metadata for the file usign the default patterns
            return [NSString stringWithFormat:@"/%@%@/%@",basePath, attachment.key,attachment.filenameBasedOnLinkMode];
        }
    }
}

-(NSString*) _URLForAttachment:(ZPZoteroAttachment*)attachment{
    NSString* baseURL;
    
    
#ifdef BETA
    NSString* appFolder = @"ZotPad-beta";
#else
    NSString* appFolder = @"ZotPad";
#endif
    
    
    if([ZPPreferences dropboxHasFullControl]){
        baseURL = @"https://www.dropbox.com/home";
    }
    else{
        baseURL = [@"https://www.dropbox.com/home/Apps/" stringByAppendingString:appFolder];
    }
    
    return [baseURL stringByAppendingPathComponent:[self _pathForAttachment:attachment]];
}

#pragma mark - Downloads

-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    DDLogInfo(@"Start downloading attachment %@ from Dropbox",attachment.filenameBasedOnLinkMode);
    
    //Link with dropBox account if not already linked
    [ZPFileChannel_Dropbox linkDropboxIfNeeded];
    
    NSString* path = [self _pathForAttachment:attachment];
    //If this is a website snapshot, we need to download all files
    
    if([ZPPreferences debugFileUploadsAndDownloads]) DDLogInfo(@"Requesting metadata from Dropbox path %@",path);
    
    //Drobbox uses NSURLconnection internally, so it needs to be called in the main thread.
    [_downloadClient performSelectorOnMainThread:@selector(loadMetadata:) withObject:[path precomposedStringWithCanonicalMapping] waitUntilDone:NO];
    
}
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    NSString* path = [self _pathForAttachment:attachment];
    [_downloadClient cancelFileLoad:[path precomposedStringWithCanonicalMapping]];
    [self cleanupAfterFinishingAttachment:attachment];
}


-(void) useProgressView:(UIProgressView*) progressView forDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    @synchronized(downloadProgressViewsByAttachment){
        //TODO: Use ID instead of key
        [downloadProgressViewsByAttachment setObject:progressView forKey:attachment.key];
    }
}

#pragma mark - Uploads

-(void) startUploadingAttachment:(ZPZoteroAttachment*)attachment overWriteConflictingServerVersion:(BOOL)overwriteConflicting{
    
    [self logVersionInformationForAttachment: attachment];
    
    DDLogInfo(@"Start uploading attachment %@ to Dropbox, overwrite: %i",attachment.filenameBasedOnLinkMode,overwriteConflicting);
    
    //Link with dropBox account if not already linked
    
    [ZPFileChannel_Dropbox linkDropboxIfNeeded];
    
    NSString* path = [self _pathForAttachment:attachment];
    
    //Drobbox uses NSURLconnection internally, so it needs to be called in the main thread.
    if (overwriteConflicting) {
        [_uploadClientThatOverwritesServerVersion performSelectorOnMainThread:@selector(loadMetadata:)
                                                                   withObject:[path precomposedStringWithCanonicalMapping]
                                                                waitUntilDone:NO];
    }
    else{
        [_uploadClientThatCreatesConflict performSelectorOnMainThread:@selector(loadMetadata:)
                                                           withObject:[path precomposedStringWithCanonicalMapping]
                                                        waitUntilDone:NO];
    }

}

-(void) useProgressView:(UIProgressView *)progressView forUploadingAttachment:(ZPZoteroAttachment *)attachment{
    @synchronized(uploadProgressViewsByAttachment){
        //TODO: Consider key collisions here. Use ID instead of key
        [uploadProgressViewsByAttachment setObject:progressView forKey:attachment.key];
    }
}

#pragma mark - Call backs

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata *)metadata {
    
    if([ZPPreferences debugFileUploadsAndDownloads]){
        DDLogInfo(@"DropBox metadata");
        DDLogInfo(@"lastModifiedDate: %@",metadata.lastModifiedDate);
        DDLogInfo(@"clientMtime: %@",metadata.clientMtime);
        DDLogInfo(@"path: %@",metadata.path);
        DDLogInfo(@"isDirectory: %i",metadata.isDirectory);
        DDLogInfo(@"hash: %@",metadata.hash);
        DDLogInfo(@"humanReadableSize: %@",metadata.humanReadableSize);
        DDLogInfo(@"root: %@",metadata.root);
        DDLogInfo(@"icon: %@",metadata.icon);
        DDLogInfo(@"rev: %@",metadata.rev);
        DDLogInfo(@"isDeleted: %i",metadata.isDeleted);
    }
    
    ZPZoteroAttachment* attachment = [self _attachmentForDBMetadata:metadata];
    
    if(client == _downloadClient){
        if (metadata.isDirectory) {
            
            if([ZPPreferences debugFileUploadsAndDownloads]) DDLogInfo(@"Folder '%@' contains:", metadata.path);
            NSString* basePath=[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%f",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
            [[NSFileManager defaultManager] createDirectoryAtPath:basePath withIntermediateDirectories:YES attributes:NULL error:NULL];
            
            NSString* path = [self _pathForAttachment:attachment];
            for (DBMetadata *file in metadata.contents) {
                if([ZPPreferences debugFileUploadsAndDownloads]) DDLogInfo(@"\t%@", file.filename);
                NSString* tempFile = [basePath stringByAppendingPathComponent:file.filename];
                [client loadFile:[[path stringByAppendingPathComponent:file.filename] precomposedStringWithCanonicalMapping] intoPath:tempFile];
            }
            @synchronized(downloadCountsByAttachment){
                //TODO: Use id instead of key
                [downloadCountsByAttachment setObject:[NSNumber numberWithInt:[metadata.contents count]] forKey:attachment.key];
            }
        }
        else{
            //Set version of the file
            if([ZPPreferences debugFileUploadsAndDownloads]) DDLogInfo(@"Start downloading file /%@/%@ (rev %@)",attachment.key,attachment.filenameBasedOnLinkMode,metadata.rev);
            NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%f",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
            NSString* path = [self _pathForAttachment:attachment];
            
            //Store the revision so that we can store it once the download finishes.
            //TODO: Use attachment ID instead
            [remoteVersions setObject:metadata.rev forKey:attachment.key];
            [client loadFile:[path precomposedStringWithCanonicalMapping] atRev:metadata.rev intoPath:tempFile];
        }
    }
    // Uploading
    else if(client == _uploadClientThatOverwritesServerVersion){

        NSString* path = [self _pathForAttachment:attachment];
        NSString* targetPath = [path stringByDeletingLastPathComponent];
        
        // Uploading will retrieve metadata only if we want to overwrite the server version. Just proceed with upload in all cases.
        
        [client uploadFile:[[path lastPathComponent] precomposedStringWithCanonicalMapping] toPath:[targetPath precomposedStringWithCanonicalMapping] withParentRev:metadata.rev fromPath:attachment.fileSystemPath_modified];
    
    }
    else if(client == _uploadClientThatCreatesConflict){
        
         //If rev is null, we assume that the file has been deleted. Fail
        
        if(metadata.rev == NULL){
            NSDictionary* userInfo = [NSDictionary dictionaryWithObject:@"The original file does not exist in Dropbox" forKey:NSLocalizedDescriptionKey];
            NSError* error = [NSError errorWithDomain:@"Dropbox"
                                                 code:-1
                                             userInfo:userInfo];
            
            [ZPFileUploadManager failedUploadingAttachment:attachment
                                                 withError:error
                                                     toURL:[self _URLForAttachment:attachment]];
            [self cleanupAfterFinishingAttachment:attachment];
        }
        else if(! [attachment.versionIdentifier_local isEqualToString:metadata.rev]){
            [self presentConflictViewForAttachment:attachment reason:[NSString stringWithFormat:@"Version identifiers differ. Local file: %@, Dropbox server file: %@", attachment.versionIdentifier_local, metadata.rev]];
        }
        else{
            NSString* path = [self _pathForAttachment:attachment];
            NSString* targetPath = [path stringByDeletingLastPathComponent];

            [client uploadFile:[[path lastPathComponent] precomposedStringWithCanonicalMapping] toPath:[targetPath precomposedStringWithCanonicalMapping] withParentRev:attachment.versionIdentifier_local fromPath:attachment.fileSystemPath_modified];
        }
        
        
    }
    
}


- (void)restClient:(DBRestClient*) client loadMetadataFailedWithError:(NSError *)error {
    
    DDLogWarn(@"Error loading Dropbox metadata: %@", error);
    
    [self _restClient:client processError:error];
    
    ZPZoteroAttachment* attachment = [self _attachmentForDBError:error];
    
    
    if(client == _downloadClient){
        [ZPFileDownloadManager failedDownloadingAttachment:attachment withError:error fromURL:[self _URLForAttachment:attachment]];
    }
    else if(client == _uploadClientThatOverwritesServerVersion){
        [ZPFileUploadManager failedUploadingAttachment:attachment withError:error toURL:[self _URLForAttachment:attachment]];
    }
    [self cleanupAfterFinishingAttachment:attachment];
    
}

// Download progresss

- (void)restClient:(DBRestClient*)client loadProgress:(CGFloat)progress forFile:(NSString*)destPath{
    
    ZPZoteroAttachment* attachment = [self _attachmentForLocalDestinationPath:destPath];
    
    if(!(attachment.linkMode == LINK_MODE_IMPORTED_URL && (
                                                           [attachment.contentType isEqualToString:@"text/html"] ||
                                                           [attachment.contentType isEqualToString:@"application/xhtml+xml"]))){
        @synchronized(downloadProgressViewsByAttachment){
            UIProgressView* progressView = [downloadProgressViewsByAttachment objectForKey:attachment.key];
            if(progressView!=NULL) [progressView setProgress:progress];
        }
    }
}
- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)localPath {
    
    if([ZPPreferences debugFileUploadsAndDownloads]) DDLogInfo(@"Dropbox returned file");
    
    ZPZoteroAttachment* attachment = [self _attachmentForLocalDestinationPath:localPath];
    
    //If this is a webpage snapshot
    if(attachment.linkMode == LINK_MODE_IMPORTED_URL && (
                                                         [attachment.contentType isEqualToString:@"text/html"] ||
                                                         [attachment.contentType isEqualToString:@"application/xhtml+xml"])){
        
        //Update progress
        //TODO: Use attachment id instead of key
        NSInteger total;
        @synchronized(downloadCountsByAttachment){
            total = [(NSNumber*)[downloadCountsByAttachment objectForKey:attachment.key] intValue];
        }
        @synchronized(downloadProgressViewsByAttachment){
            UIProgressView* progressView = [downloadProgressViewsByAttachment objectForKey:attachment.key];
            if(progressView!=NULL) [progressView setProgress:(total-[client requestCount]+1)/ (float) total];
        }
        
        if([client requestCount]==1){
            
            @synchronized(downloadCountsByAttachment){
                [downloadCountsByAttachment removeObjectForKey:[self keyForRequest:client]];
            }
            
            //All done
            
            
            NSString* zipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%f",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
            
            ZipArchive* zipArchive = [[ZipArchive alloc] init];
            
            [zipArchive CreateZipFile2:zipFilePath];
            
            //Encode the filenames
            
            NSString* tempPath = [localPath stringByDeletingLastPathComponent];
            
            NSArray* files = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:tempPath error:NULL];
            
            for (NSString* file in files){
                // The filenames end with %ZB64, which needs to be removed
                NSString* encodedFilename = [ZPZoteroAttachment zoteroBase64Encode:[file lastPathComponent]];
                if([ZPPreferences debugFileUploadsAndDownloads]) DDLogInfo(@"Encoded %@ as %@",file , encodedFilename);
                
                //Add to Zip with the new name
                [zipArchive addFileToZip:[tempPath stringByAppendingPathComponent:file] newname:encodedFilename];
                
                [[NSFileManager defaultManager] moveItemAtPath:file toPath:encodedFilename error:NULL];
                
            }
            
            //Create an archive
            
            [zipArchive CloseZipFile2];
            
            [[NSFileManager defaultManager] removeItemAtPath:tempPath error:NULL];
            
            localPath = zipFilePath;
            
            //Website snapshots do not use revision info in Dropbox

            [ZPFileDownloadManager finishedDownloadingAttachment:attachment toFileAtPath:localPath withVersionIdentifier:@"" ];
            [self cleanupAfterFinishingAttachment:attachment];
        }
    }
    else{
        //TODO: Use attachment ID instead
        [ZPFileDownloadManager finishedDownloadingAttachment:attachment toFileAtPath:localPath withVersionIdentifier:[remoteVersions objectForKey:attachment.key]];
        [self cleanupAfterFinishingAttachment:attachment];
    }
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error {
    DDLogWarn(@"There was an error downloading the file - %@", error);
    
    [self _restClient:client processError:error];
    
    ZPZoteroAttachment* attachment = [self _attachmentForDBError:error];
    [ZPFileDownloadManager failedDownloadingAttachment:attachment withError:error fromURL:[self _URLForAttachment:attachment]];
    [self cleanupAfterFinishingAttachment:attachment];
    
}

- (void)restClient:(DBRestClient*)client uploadedFile:(NSString*)destPath from:(NSString*)srcPath
          metadata:(DBMetadata*)metadata{
    
    if([ZPPreferences debugFileUploadsAndDownloads]) DDLogInfo(@"Dropbox uploaded file");
    
    ZPZoteroAttachment* attachment = [self _attachmentForRemotePath:destPath];
    [ZPFileUploadManager finishedUploadingAttachment:attachment withVersionIdentifier:metadata.rev];
    [self cleanupAfterFinishingAttachment:attachment];
    
}
- (void)restClient:(DBRestClient*)client uploadProgress:(CGFloat)progress forFile:(NSString*)destPath from:(NSString*)srcPath{
    
    ZPZoteroAttachment* attachment = [self _attachmentForRemotePath:destPath];
    
    @synchronized(uploadProgressViewsByAttachment){
        //TODO: Use id instead of key for attachment
        UIProgressView* progressView = [uploadProgressViewsByAttachment objectForKey:attachment.key];
        if(progressView!=NULL) [progressView setProgress:progress];
    }
    
}
- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error{

    DDLogWarn(@"There was an error uploading the file - %@", error);
    
    [self _restClient:client processError:error];
    
    ZPZoteroAttachment* attachment = [self _attachmentForDBError:error];

    [ZPFileUploadManager failedUploadingAttachment:attachment withError:error toURL:[self _URLForAttachment:attachment]];
    [self cleanupAfterFinishingAttachment:attachment];
}


-(void) removeProgressView:(UIProgressView*) progressView{
    
    @synchronized(downloadProgressViewsByAttachment){
        for (NSObject* key in downloadProgressViewsByAttachment){
            if([downloadProgressViewsByAttachment objectForKey:key] == progressView){
                [downloadProgressViewsByAttachment removeObjectForKey:key];
            }
        }
    }
    
    @synchronized(uploadProgressViewsByAttachment){
        for (NSObject* key in uploadProgressViewsByAttachment){
            if([uploadProgressViewsByAttachment objectForKey:key] == progressView){
                [uploadProgressViewsByAttachment removeObjectForKey:key];
            }
        }
    }

}

#pragma DBSession delegate

- (void)sessionDidReceiveAuthorizationFailure:(ZPDBSession *)session userId:(NSString *)userId{
    DDLogError(@"Authorization failure with Dropbox for user ID %@. Will unlink and attemp to relink later.",userId);
    if(userId != NULL){
        [[ZPDBSession sharedSession] unlinkAll];
    }
}

#pragma mark - Utility methdods

-(void) _restClient:(DBRestClient*) client processError:(NSError *)error{
    //If we are not linked, link
    if(error.code==401){
        [ZPFileChannel_Dropbox linkDropboxIfNeeded];
    }
    
}

-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment*)attachment{
    
    @synchronized(uploadProgressViewsByAttachment){
        //TODO: Use attachment ID instead
        [uploadProgressViewsByAttachment removeObjectForKey:attachment.key];
    }

    @synchronized(downloadProgressViewsByAttachment){
        //TODO: Use attachment ID instead
        [downloadProgressViewsByAttachment removeObjectForKey:attachment.key];
    }
    
    [super cleanupAfterFinishingAttachment:attachment];
}

-(ZPZoteroAttachment*) _attachmentForDBMetadata:(DBMetadata*)metadata{
    ZPZoteroAttachment* attachment = [self _attachmentForRemotePath:metadata.path];
    return attachment;
}

-(ZPZoteroAttachment*) _attachmentForDBError:(NSError *)error{
    NSDictionary* userInfo = error.userInfo;
    NSString* path = [userInfo objectForKey:@"path"];
    ZPZoteroAttachment* attachment = [self _attachmentForRemotePath:path];
    return attachment;
}

-(ZPZoteroAttachment*) _attachmentForLocalDestinationPath:(NSString*)destPath{

    
    NSString* key = [destPath substringWithRange:NSMakeRange([NSTemporaryDirectory() length]+2, 8)];
    return [ZPZoteroAttachment attachmentWithKey:key];
    
}

-(ZPZoteroAttachment*) _attachmentForRemotePath:(NSString*)path{
    NSArray* pathComponents = [path pathComponents];
    
    ZPZoteroAttachment* attachment = NULL;
    NSString* filename = [pathComponents lastObject];
    
    // Match based on key and filename
    
    if([pathComponents count]>=2){
        NSString* key = [pathComponents objectAtIndex:[pathComponents count]-2];
        
        // Is the second to last path component of correct lenght to be a key
        
        if([key length]==8){
            attachment = [ZPZoteroAttachment attachmentWithKey:key];
        
            //Verify that the filename matches. If not
            if(! [filename isEqualToString:attachment.filenameBasedOnLinkMode]){
                DDLogWarn(@"File name in Dropbox (%@) does not match the local filename (%@) for item with key %@",
                      filename, attachment.filenameBasedOnLinkMode, key);
                attachment = nil;
            }
        }
    }
    
    // Try matching based on file name pattern

    if(attachment == nil && [ZPPreferences useCustomFilenamesWithDropbox]){
        //Loop over all attachments to identify which file this belongs to
        for(NSString* key in [ZPDatabase allAttachmentKeys]){
            attachment = [ZPZoteroAttachment attachmentWithKey:key];
            NSString* pathToTest = [self _pathForAttachment:attachment];
            if([pathToTest isEqualToString:path]) break;
            else attachment = nil;
        }
        
    }
    
    if(attachment == nil) DDLogError(@"Attachment could not be identified for remote path %@", path);
    NSAssert(attachment != nil, @"Attachment could not be identified for remote path %@", path);

    return attachment;
}



@end
