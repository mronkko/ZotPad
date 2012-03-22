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

#import "ZPLogger.h"


@interface ZPQuicklookController(){
    ZPZoteroAttachment* _currentAttachment;
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



#pragma mark Item downloading

- (void) _downloadWithProgressAlert:(ZPZoteroAttachment *)attachment {
    
    UIAlertView* progressAlert;

    progressAlert = [[UIAlertView alloc] initWithTitle: [NSString stringWithFormat:@"Downloading (%i KB)",[attachment.attachmentSize intValue]/1024]
                                                message: nil
                                               delegate: self
                                      cancelButtonTitle: nil
                                      otherButtonTitles: nil];
    
    // Create the progress bar and add it to the alert
    UIProgressView *progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(30.0f, 80.0f, 225.0f, 90.0f)];
    [progressAlert addSubview:progressView];
    [progressView setProgressViewStyle: UIProgressViewStyleBar];
    [progressAlert show];
    
    //Create an invocation
    SEL selector = @selector(_downloadAttachment:withUIProgressView:progressAlert:);
    
    NSMethodSignature* signature = [[self class] instanceMethodSignatureForSelector:selector];
    NSInvocation* invocation  = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:self];
    [invocation setSelector:selector];
    
    //Set arguments
    [invocation setArgument:&attachment atIndex:2];
    [invocation setArgument:&progressView atIndex:3];
    [invocation setArgument:&progressAlert atIndex:4];
    
    [invocation performSelectorInBackground:@selector(invoke) withObject:NULL];
}

- (void) _downloadAttachment:(ZPZoteroAttachment *)attachment withUIProgressView:(UIProgressView*) progressView progressAlert:(UIAlertView*)progressAlert{
    [[ZPServerConnection instance] downloadAttachment:attachment withUIProgressView:progressView];
    [progressAlert dismissWithClickedButtonIndex:0 animated:YES];
    [_fileURLs addObject:attachment.fileSystemPath];
    [self performSelectorOnMainThread:@selector(_displayQuickLook) withObject:NULL waitUntilDone:NO];
}


@end
