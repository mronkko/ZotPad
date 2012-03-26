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


@interface ZPQuicklookController(){
    ZPZoteroAttachment* _activeAttachment;
}
- (void) _downloadWithProgressAlert:(ZPZoteroAttachment *)attachment;
- (void) _downloadAttachment:(ZPZoteroAttachment *)attachment withUIProgressView:(UIProgressView*) progressView progressAlert:(UIAlertView*)progressAlert;
- (void) _displayQuicklook;
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

-(void) openItemInQuickLook:(ZPZoteroItem*)item attachmentIndex:(NSInteger)index sourceView:(UIViewController*)view{
    
    ZPZoteroAttachment* attachment = [item.attachments objectAtIndex:index];
    _source = view;
    // Mark this file as recently viewed. This will be done also in the case
    // that the file cannot be downloaded because the fact that user tapped an
    // item is still relevant information for the cache controller
 
    
    [[ZPDatabase instance] updateViewedTimestamp:attachment];
    
    if(! attachment.fileExists){
        if([[ZPPreferences instance] online] && [[ZPServerConnection instance] hasInternetConnection]) [self _downloadWithProgressAlert:attachment];
    }
    else {
        [_fileURLs addObject:attachment.fileSystemPath];
        [self _displayQuicklook];
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



#pragma mark - Item downloading and alert view

- (void) _downloadWithProgressAlert:(ZPZoteroAttachment *)attachment {
    
    NSString* title;
    if (attachment.attachmentSize != [NSNull null]){
        title = [NSString stringWithFormat:@"Downloading (%i KB)",[attachment.attachmentSize intValue]/1024];
    }
    else {
        title = @"Locating and downloading";
    }
    
    _progressAlert = [[UIAlertView alloc] initWithTitle: title
                                                message: @" "
                                               delegate: self
                                      cancelButtonTitle: @"Cancel"
                                      otherButtonTitles: nil];
    
    _activeAttachment = attachment;
    
    // Create the progress bar and add it to the alert
    UIProgressView *progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(30.0f, 55.0f, 225.0f, 90.0f)];
    [_progressAlert addSubview:progressView];
    [progressView setProgressViewStyle: UIProgressViewStyleBar];
    [_progressAlert show];
    
    [[ZPDataLayer instance] registerAttachmentObserver:self];
    // Start downloading
    [[ZPServerConnection instance] startDownloadingAttachment:attachment];
    [[ZPServerConnection instance] useProgressView:progressView forAttachment:attachment];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if(_activeAttachment!=NULL){
        [[ZPServerConnection instance] cancelDownloadingAttachment: _activeAttachment];
    }
}

-(void) notifyAttachmentDownloadCompleted:(ZPZoteroAttachment*) attachment{

    if (_activeAttachment == attachment){
        
        //No need to be notified about new completed downloads
        [[ZPDataLayer instance] removeAttachmentObserver:self];

        _activeAttachment = NULL;
        if(attachment.fileExists){
            [_progressAlert dismissWithClickedButtonIndex:0 animated:YES];
            [_fileURLs addObject:attachment.fileSystemPath];
            [self performSelectorOnMainThread:@selector(_displayQuicklook) withObject:NULL waitUntilDone:NO];
        }
        else{
            //Remove the progressView and show an error message instead
            for(UIView* view in [_progressAlert subviews]){
                if([view isKindOfClass:[UIProgressView class]]) [view removeFromSuperview];
            }
            [_progressAlert setMessage:@"Dowloading failed"];
        }
        _progressAlert = NULL;
    }
}

@end
