//
//  ZPThumbnailButtonTarget.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 1/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ZPFileThumbnailAndQuicklookController.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroAttachment.h"
#import "ZPDatabase.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import "ZPItemDetailViewController.h"
#import "ZPServerConnection.h"

#import "ZPPreferences.h"

#import "ZPLogger.h"


@interface ZPFileThumbnailAndQuicklookController(){
    ZPZoteroAttachment* _currentAttachment;
}
- (void) _downloadWithProgressAlert:(ZPZoteroAttachment *)attachment;
- (void) _downloadAttachment:(ZPZoteroAttachment *)attachment withUIProgressView:(UIProgressView*) progressView progressAlert:(UIAlertView*)progressAlert;


-(void) _configureButton:(UIButton*) button;

@end



@implementation ZPFileThumbnailAndQuicklookController

static NSCache* _fileTypeImageCache;

-(id) initWithItem:(ZPZoteroItem*)item viewController:(UIViewController*) viewController maxHeight:(NSInteger)maxHeight maxWidth:(NSInteger)maxWidth{
    
    if(_fileTypeImageCache == NULL){
        _fileTypeImageCache = [[NSCache alloc] init];
    }
    
    self = [super init];
    _item= item;
    _viewController=viewController;
    _maxWidth=maxWidth;
    _maxHeight=maxHeight;
    
    return self;
}

-(void) buttonTapped:(id)sender{
    
    
    //Get the table cell.
    UITableViewCell* cell = (UITableViewCell* )[[sender superview] superview];
    
    //Get the row of this cell
    NSInteger row = [[(ZPSimpleItemListViewController*) _viewController tableView] indexPathForCell:cell].row;
    
    ZPZoteroItem* item = [ZPZoteroItem retrieveOrInitializeWithKey:[[(ZPSimpleItemListViewController*) _viewController itemKeysShown] objectAtIndex:row]];
    
    _currentAttachment = [item.attachments objectAtIndex:0];
    if(_currentAttachment.fileExists || [[ZPPreferences instance] online]){
        [self openInQuickLookWithAttachment:_currentAttachment];
        
    }
}

#pragma mark QuickLook delegate methods

- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller 
{
    NSLog(@"Number of previews for item %@ is %i",_item.title, [[_item allExistingAttachments] count] );
    return [[_item allExistingAttachments] count];
}


- (id <QLPreviewItem>) previewController: (QLPreviewController *) controller previewItemAtIndex: (NSInteger) index{

    NSLog(@"Opening preview %i for item %@",index,_item.title );

    NSArray* allExisting = [_item allExistingAttachments];
    ZPZoteroAttachment* currentAttachment = [allExisting objectAtIndex:index];
    NSString* path = [currentAttachment fileSystemPath];
    return [NSURL fileURLWithPath:path];
}


-(void) openInQuickLookWithAttachment:(ZPZoteroAttachment*) attachment{

    // Mark these items as recently viewed. This will be done also in the case
    // that the file cannot be downloaded because the fact that user tapped an
    //item is still relevant information for the cache controller
    
    _item = [ZPZoteroItem retrieveOrInitializeWithKey:attachment.parentItemKey];
    for(ZPZoteroAttachment* attachment in [_item allExistingAttachments]){
        [[ZPDatabase instance] updateViewedTimestamp:attachment];
    }

    if(! attachment.fileExists){
        if([[ZPPreferences instance] online]) [self _downloadWithProgressAlert:attachment];
    }
    else {
        
        QLPreviewController *quicklook = [[QLPreviewController alloc] init];
        [quicklook setDataSource:self];
        NSInteger index = [[_item allExistingAttachments] indexOfObject:attachment];
        [quicklook setCurrentPreviewItemIndex:index];
        UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;       
        [root presentModalViewController:quicklook animated:YES];
        
    }
}


-(UIImage*) getFiletypeImage:(ZPZoteroAttachment*)attachment{

    
    NSString* key = [NSString stringWithFormat:@"%@%ix%i",attachment.attachmentType,_maxHeight,_maxWidth];
    
    UIImage* image = [_fileTypeImageCache objectForKey:key];
    
    if(image==NULL){
        NSLog(@"Getting file type image for %@ (%ix%i)",attachment.attachmentType,_maxHeight,_maxWidth);
        
        // Source: http://stackoverflow.com/questions/5876895/using-built-in-icons-for-mime-type-or-uti-type-in-ios
        
        //Need to initialize this way or the doc controller doesn't work
        NSURL*fooUrl = [NSURL URLWithString:@"file://foot.dat"];
        UIDocumentInteractionController* docController = [UIDocumentInteractionController interactionControllerWithURL:fooUrl];
        
        //Need to convert from mime type to a UTI to be able to get icons for the document
        CFStringRef mime = (__bridge CFStringRef) attachment.attachmentType;
        NSString *uti = (__bridge NSString*) UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType,mime, NULL);
        
        //Tell the doc controller what UTI type we want
        docController.UTI = uti;
        
        //Get the largest image that can fit
        
        for(UIImage* icon in docController.icons) {
            
            if(icon.size.width<_maxWidth && icon.size.height<_maxHeight) image=icon;
            else{
                if(image==NULL) image=icon;
                break;   
            }
        }

        NSLog(@"Using image with size ( %f x %f )",image.size.width,image.size.height);

        [_fileTypeImageCache setObject:image forKey:key];
    }

    return image;
}


-(void) configureButton:(UIButton*) button withAttachment:(ZPZoteroAttachment*)attachment{

    
    UIImage* image = [self getFiletypeImage:attachment];
    [button setImage:image forState:UIControlStateNormal];
    [button setNeedsDisplay];
    
    if(attachment.fileExists || [[ZPPreferences instance] online]){
        [button setAlpha:1];
        [button addTarget:self action:@selector(buttonTapped:) 
            forControlEvents:UIControlEventTouchUpInside];
    }
    else{
        [button setAlpha:.25];
    }
}


#pragma mark Item downloading

- (void) _downloadWithProgressAlert:(ZPZoteroAttachment *)attachment {
    
    UIAlertView* progressAlert;

    progressAlert = [[UIAlertView alloc] initWithTitle: [NSString stringWithFormat:@"Downloading (%i KB)",attachment.attachmentLength/1024]
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
    [self performSelectorOnMainThread:@selector(openInQuickLookWithAttachment:) withObject:attachment waitUntilDone:NO];
}


@end
