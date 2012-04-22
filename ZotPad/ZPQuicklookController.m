//
//  ZPThumbnailButtonTarget.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 1/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ZPQuicklookController.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroAttachment.h"
#import "ZPDatabase.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import "ZPItemDetailViewController.h"
#import "ZPServerConnection.h"

#import "ZPPreferences.h"
#import "ZPDataLayer.h"
#import "ZPLogger.h"

//Unzipping and base64 decoding
#import "ZipArchive.h"
#import "QSStrings.h"



@interface ZPQuicklookController(){
    ZPZoteroAttachment* _activeAttachment;
}
- (void) _displayQuicklook;
- (void) _addAttachmentToQuicklook:(ZPZoteroAttachment *)attachment;

@end



@implementation ZPQuicklookController


static ZPQuicklookController* _instance;

+(ZPQuicklookController*) instance{
    if(_instance == NULL){
        _instance = [[ZPQuicklookController alloc] init];
    }
    return _instance;
}

-(id) init{
    self = [super init];
    _fileURLs = [[NSMutableArray alloc] init];
    return self;
}

-(void) openItemInQuickLook:(ZPZoteroAttachment*)attachment sourceView:(UIViewController*)view{
    
    _source = view;
    // Mark this file as recently viewed. This will be done also in the case
    // that the file cannot be downloaded because the fact that user tapped an
    // item is still relevant information for the cache controller
 
    
    [[ZPDatabase instance] updateViewedTimestamp:attachment];
    
    if(! attachment.fileExists){
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"File not found"
                                                          message:[NSString stringWithFormat:@"The file %@ was not found on ZotPad.",attachment.filename]
                                                         delegate:nil
                                                cancelButtonTitle:@"Cancel"
                                                otherButtonTitles:nil];
        
        [message show];
    }
    else {
        [self _addAttachmentToQuicklook:attachment];
        [self _displayQuicklook];
    }
}


- (void) _addAttachmentToQuicklook:(ZPZoteroAttachment *)attachment{
    
    // Imported URLs need to be unzipped
    if([attachment.linkMode isEqualToString:@"imported_url"] ){
        
        NSString* tempDir = NSTemporaryDirectory();
        ZipArchive* zipArchive = [[ZipArchive alloc] init];
        [zipArchive UnzipOpenFile:attachment.fileSystemPath];
        [zipArchive UnzipFileTo:tempDir overWrite:YES];
        [zipArchive UnzipCloseFile];

        //List the unzipped files and decode them
        
        NSArray* files = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:tempDir error:NULL];
        
        for (NSString* file in files){
            NSLog(@"Unzipped file %@ into temp dir %@",file,tempDir);
            // The filenames end with %ZB64, which needs to be removed
            NSString* toBeDecoded = [file substringToIndex:[file length] - 5];
            NSData* decodedData = [QSStrings decodeBase64WithString:toBeDecoded] ;
            NSString* decodedFilename = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
            NSLog(@"Decoded %@ as %@",toBeDecoded, decodedFilename);
        
            [[NSFileManager defaultManager] moveItemAtPath:[tempDir stringByAppendingPathComponent:file] toPath:[tempDir stringByAppendingPathComponent:decodedFilename] error:NULL];

        }
        
        [_fileURLs addObject:[tempDir stringByAppendingPathComponent:attachment.filename]];
    }
    else{
        [_fileURLs addObject:attachment.fileSystemPath];
    }
}


- (void) _displayQuicklook{
    QLPreviewController *quicklook = [[QLPreviewController alloc] init];
    [quicklook setDataSource:self];
    [quicklook setCurrentPreviewItemIndex:[_fileURLs count]-1];
    [_source presentModalViewController:quicklook animated:YES];
    
}


#pragma mark QuickLook delegate methods

- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller 
{
    return [_fileURLs count];
}


- (id <QLPreviewItem>) previewController: (QLPreviewController *) controller previewItemAtIndex: (NSInteger) index{
    return [NSURL fileURLWithPath:[_fileURLs objectAtIndex:index]];
}



@end
