//
//  ZPAttachmentCarouselDelegate.m
//  ZotPad
//
//  This class assumes that there is only one carousel that it serves
//
//
//  Created by Mikko Rönkkö on 25.6.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPAttachmentCarouselDelegate.h"

#import "ZPAttachmentIconImageFactory.h"
#import <QuartzCore/QuartzCore.h>
#import <zlib.h>
#import "ZPFileViewerViewController.h"
#import "ZPFileChannel.h"
#import "ZPFileDownloadManager.h"
#import "ZPReachability.h"

NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC = 0;
NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD = 1;
NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD = 2;
NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_FIRST_STATIC_SECOND_DOWNLOAD = 3;

NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_ORIGINAL = 10;
NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_MODIFIED = 11;
NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_FIRST_MODIFIED_SECOND_ORIGINAL = 12;


//The tags are negative, because iCarousel adds positive tags to the root views

NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_TAG_FILEIMAGE = -1;
NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_TAG_ERRORLABEL = -2;
NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_TAG_STATUSLABEL = -3;
NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_TAG_PROGRESSVIEW = -4;
NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_TAG_TITLELABEL = -5;


@interface ZPAttachmentCarouselDelegate(){
    NSMutableSet* _progressViews;
}

-(BOOL) _fileExistsForAttachment:(ZPZoteroAttachment*) attachment;
-(void) _configureFileImageView:(UIImageView*) imageView withAttachment:(ZPZoteroAttachment*)attachment;
-(void) _configureProgressLabel:(UILabel*) label withAttachment:(ZPZoteroAttachment*)attachment;
-(NSInteger) _modeForAttachment:(ZPZoteroAttachment*)attachment;
-(NSInteger) _showForAttachment:(ZPZoteroAttachment*)attachment;
-(void) _setLabelsForAttachment:(ZPZoteroAttachment*)attachment progressText:(NSString*)progressText errorText:(NSString*)errorText mode:(NSInteger)mode reconfigureIcon:(BOOL)reconfigureIcon;

@end


@implementation ZPAttachmentCarouselDelegate

@synthesize actionButton, attachmentCarousel, mode, show, owner;
@synthesize selectedIndex=_selectedIndex;

-(id) init{
    self = [super init];

    //Register self as observer for item downloads
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAttachmentDownloadCompleted:) name:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FINISHED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAttachmentDownloadFailed:) name:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FAILED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAttachmentDownloadStarted:) name:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_STARTED object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAttachmentDeleted:) name:ZPNOTIFICATION_ATTACHMENT_FILE_DELETED object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAttachmentUploadCompleted:) name:ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_FINISHED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAttachmentUploadFailed:) name:ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_FAILED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAttachmentUploadStarted:) name:ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_STARTED object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyItemsAvailable:) name:ZPNOTIFICATION_ITEMS_AVAILABLE object:nil];
    
    _progressViews = [[NSMutableSet alloc] init];
    
    return self;
}

-(void) dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



-(void) configureWithAttachmentArray:(NSArray*) attachments{
    _item = NULL;
    _attachments = attachments;
    _latestManuallyTriggeredAttachment = NULL;
}
-(void) configureWithZoteroItem:(ZPZoteroItem*) item{
    _item = item;
    _attachments = item.attachments;
    _latestManuallyTriggeredAttachment = NULL;
}

-(void) unregisterProgressViewsBeforeUnloading{
    for(UIProgressView* progressView in _progressViews){
         [ZPFileChannel removeProgressView:progressView];
    }
}


/*
 
 This is needed because the different show-values that the carousel can have
 
 */
-(BOOL) _fileExistsForAttachment:(ZPZoteroAttachment*) attachment{
    if(show == ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_ORIGINAL){
        return attachment.fileExists_original;
    }
    else return(attachment.fileExists);
}

#pragma mark - iCarousel delegate


- (NSUInteger)numberOfPlaceholdersInCarousel:(iCarousel *)carousel{
    NSAssert(carousel==self.attachmentCarousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");
    return 0;
}

- (NSUInteger)numberOfItemsInCarousel:(iCarousel *)carousel
{
    NSAssert(carousel==self.attachmentCarousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");
    return [_attachments count];
}


- (NSUInteger) numberOfVisibleItemsInCarousel:(iCarousel*)carousel{
    NSAssert(carousel==self.attachmentCarousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");
    NSInteger numItems = [self numberOfItemsInCarousel:carousel];
    NSInteger ret=  MAX(numItems,5);
    return ret;
}

- (UIView *)carousel:(iCarousel *)carousel viewForItemAtIndex:(NSUInteger)index reusingView:(UIView*)view
{
    NSAssert(carousel==self.attachmentCarousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");
  
    if(view != NULL && view.tag == index) return view;

    
    ZPZoteroAttachment* attachment = [_attachments objectAtIndex:index];
    

    UIImageView* fileImage;
    UIProgressView* progressView;
    UILabel* titleLabel;
    UILabel* progressLabel;
    UILabel* errorLabel;
    
    if(view==NULL){
        //Construct a blank view
        
        NSInteger height = carousel.frame.size.height*0.95;
        NSInteger width= height/1.4142;
        
        view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width,height)];
        view.backgroundColor = [UIColor whiteColor];
        view.layer.borderWidth = 2.0f;
        view.tag = index;
        
        fileImage = [[UIImageView alloc] initWithFrame:CGRectMake(0,(height-width)/2, width, width)];
        fileImage.tag = ZPATTACHMENTICONGVIEWCONTROLLER_TAG_FILEIMAGE;
        [view addSubview:fileImage];
        
        NSInteger labelHeight = height*2/5;
        NSInteger labelWidth = width*4/5;
        
        UIView* labelBackground = [[UIView alloc] initWithFrame:CGRectMake((width-labelWidth)/2, (height-labelHeight)/2, labelWidth, labelHeight)];
        labelBackground.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:.5];
        labelBackground.layer.cornerRadius = 8;
        [view addSubview:labelBackground];
        
        NSInteger labelSubviewOffset = 10;
        NSInteger labelSubviewWidth = labelWidth-2*labelSubviewOffset; 
        NSInteger labelSubviewHeight = labelHeight-2*labelSubviewOffset;

        titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(labelSubviewOffset, labelSubviewOffset, labelSubviewWidth, labelSubviewHeight*.6)];
        titleLabel.numberOfLines = 4;
        titleLabel.tag = ZPATTACHMENTICONGVIEWCONTROLLER_TAG_TITLELABEL;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textColor = [UIColor whiteColor];
        
        [labelBackground addSubview:titleLabel];
        
        progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(labelSubviewOffset, labelSubviewOffset + labelSubviewHeight*.6, labelSubviewWidth, labelSubviewHeight*.15)];
        progressLabel.tag = ZPATTACHMENTICONGVIEWCONTROLLER_TAG_STATUSLABEL;
        progressLabel.backgroundColor = [UIColor clearColor];
        progressLabel.textColor = [UIColor whiteColor];

        [labelBackground addSubview: progressLabel];
        
        progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(labelSubviewOffset, labelSubviewOffset + labelSubviewHeight*.75, labelSubviewWidth, labelSubviewHeight*.15)];

        //Store the view so that we can unregister them later
        [_progressViews addObject:progressView];
        
        progressView.tag = ZPATTACHMENTICONGVIEWCONTROLLER_TAG_PROGRESSVIEW;
        progressView.backgroundColor = [UIColor clearColor];
        
        [labelBackground addSubview: progressView];
        
        errorLabel = [[UILabel alloc] initWithFrame:CGRectMake(labelSubviewOffset, labelSubviewOffset + labelSubviewHeight*.75, labelSubviewWidth, labelSubviewHeight*.25)];
        errorLabel.tag = ZPATTACHMENTICONGVIEWCONTROLLER_TAG_ERRORLABEL;
        errorLabel.backgroundColor = [UIColor clearColor];
        errorLabel.textColor = [UIColor whiteColor];
        
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
            errorLabel.font = [UIFont systemFontOfSize:12];
        }
        else {
            errorLabel.font = [UIFont systemFontOfSize:10];
        }
        
        errorLabel.numberOfLines = 4;
        [labelBackground addSubview:errorLabel];
        
        
    }
    else{
        
        fileImage = (UIImageView*)[view viewWithTag:ZPATTACHMENTICONGVIEWCONTROLLER_TAG_FILEIMAGE];
        titleLabel = (UILabel*)[view viewWithTag:ZPATTACHMENTICONGVIEWCONTROLLER_TAG_TITLELABEL];
        progressLabel = (UILabel*)[view viewWithTag:ZPATTACHMENTICONGVIEWCONTROLLER_TAG_STATUSLABEL];
        progressView = (UIProgressView*)[view viewWithTag:ZPATTACHMENTICONGVIEWCONTROLLER_TAG_PROGRESSVIEW];
        errorLabel = (UILabel*)[view viewWithTag:ZPATTACHMENTICONGVIEWCONTROLLER_TAG_ERRORLABEL];
    }


    [self _configureFileImageView:fileImage withAttachment:attachment];
    [self _configureProgressLabel:progressLabel withAttachment:attachment];

    titleLabel.text = attachment.title;
    errorLabel.hidden = TRUE;
    
    //TODO: Recycle progressviews better using notifications
    progressView.hidden=TRUE;
    
    return view;
}

-(NSInteger) _modeForAttachment:(ZPZoteroAttachment*)attachment{
    if(self.mode == ZPATTACHMENTICONGVIEWCONTROLLER_MODE_FIRST_STATIC_SECOND_DOWNLOAD){
        if([_attachments objectAtIndex:0] == attachment) return ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC;
        else return ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD;
    }
    else return self.mode;
}

-(NSInteger) _showForAttachment:(ZPZoteroAttachment*)attachment{
    if(self.mode == ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_FIRST_MODIFIED_SECOND_ORIGINAL){
        if([_attachments objectAtIndex:0] == attachment) return ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_MODIFIED;
        else return ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_ORIGINAL;
    }
    else return self.show;
}


-(void) _configureFileImageView:(UIImageView*) imageView withAttachment:(ZPZoteroAttachment*)attachment{
    
    //TODO: Cache rendered PDF images

    if([attachment.contentType isEqualToString:@"application/pdf"] && 
        (attachment.linkMode == LINK_MODE_IMPORTED_FILE ||
         attachment.linkMode == LINK_MODE_IMPORTED_URL)){
        
        NSString* path;
        if([self _showForAttachment:attachment] == ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_ORIGINAL){
            path =attachment.fileSystemPath_original;
        }
        else{
            path =attachment.fileSystemPath;    
        }
        
        if([[NSFileManager defaultManager] fileExistsAtPath:path]){
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{
                [ZPAttachmentIconImageFactory renderPDFPreviewForFileAtPath:path intoImageView:imageView];
            });
        }
        
    }
    
    // Assing a place holder icon if the current icon is null while we wait for the previews to render
    if(imageView.image == nil){
        [ZPAttachmentIconImageFactory renderFileTypeIconForAttachment:attachment intoImageView:imageView];
    }
}


-(void) _configureProgressLabel:(UILabel*) label withAttachment:(ZPZoteroAttachment*)attachment{

    NSInteger thisMode = [self _modeForAttachment:attachment];
    NSInteger thisShow = [self _showForAttachment:attachment];
                          
    if(thisMode == ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD){

        if([ZPFileDownloadManager isAttachmentDownloading:attachment]){
            [self notifyAttachmentDownloadStarted:[NSNotification notificationWithName:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_STARTED object:attachment]];
        }
        else{
            
            //Imported files and URLs have files that can be downloaded
            
            NSInteger linkMode = attachment.linkMode;
            BOOL exists;
            if(thisShow == ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_ORIGINAL){
                exists = [attachment fileExists_original];
            }
            else{
                exists = [attachment fileExists];
            }
            if((linkMode == LINK_MODE_IMPORTED_FILE || linkMode == LINK_MODE_IMPORTED_URL ||
                (linkMode == LINK_MODE_LINKED_FILE && [ZPPreferences downloadLinkedFilesWithDropbox]))
               && ! exists ){
                                
                if([ZPPreferences online]){
                    
                    //TODO: Check if already downloading.
                    
                    if ([ZPPreferences useDropbox]) label.text = @"Download from Dropbox";
                    else if([ZPPreferences useWebDAV] && attachment.libraryID == LIBRARY_ID_MY_LIBRARY) label.text = @"Download from WebDAV";
                    else{
                        
                        if (attachment.existsOnZoteroServer){
                            if(attachment.attachmentSize!= 0){
                                label.text =  [NSString stringWithFormat:@"Download from Zotero (%i KB)",attachment.attachmentSize/1024];
                            }
                            else{
                                label.text = @"Download from Zotero";
                            }
                        }
                        else label.text = @"File does not exist on Zotero server";
                    }
                }
                else  label.text = @"File cannot be downloaded when offline";
            }
            
            // Linked URL will be shown directly from web 
            
            else if (attachment.linkMode == LINK_MODE_LINKED_URL &&
                     !  [ZPPreferences online]){
                label.text = @"Linked URL cannot be viewed in offline mode";
                
            }
            
            //Linked files are available only on the computer where they were created
            
            else if (attachment.linkMode == LINK_MODE_LINKED_FILE) {
                label.text = @"Linked files cannot be viewed in ZotPad";
            }
            
            else{
                label.hidden = TRUE;
            }
        }    
    }
    
    
    
    
    
    else if(self.mode == ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD){
        label.hidden = FALSE;
        
        if([ZPFileDownloadManager isAttachmentDownloading:attachment]){
            [self notifyAttachmentDownloadStarted:[NSNotification notificationWithName:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_STARTED object:attachment]];
        }
        else{
            label.text = @"Added to upload queue";
        }    
    }
    if(self.mode == ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC){
        if(attachment.fileExists)
            label.hidden =TRUE;
        else
            label.text = @"File not found";
    }
    
}


//This is implemented because it is a mandatory protocol method
- (UIView *)carousel:(iCarousel *)carousel placeholderViewAtIndex:(NSUInteger)index reusingView:(UIView *)view{
    NSAssert(carousel==self.attachmentCarousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");
    return view;
}

- (void)carousel:(iCarousel *)carousel didSelectItemAtIndex:(NSInteger)index{
    NSAssert(carousel==self.attachmentCarousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");
    if([carousel currentItemIndex] == index){
        
        ZPZoteroAttachment* attachment = [_attachments objectAtIndex:index]; 
        
        if([self _fileExistsForAttachment:attachment]){
            UIView* sourceView;
            for(sourceView in carousel.visibleItemViews){
                if([carousel indexOfItemView:sourceView] == index){
                    break;   
                }
            }
            
            [ZPFileViewerViewController presentWithAttachment:attachment];
           
        }
        else if(attachment.linkMode == LINK_MODE_LINKED_URL && [ZPReachability hasInternetConnection]){
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:attachment.url]];
        }
        else if(self.mode == ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD && ( attachment.linkMode == LINK_MODE_IMPORTED_FILE || 
                attachment.linkMode == LINK_MODE_IMPORTED_URL)){
            

            
            
            if([ZPReachability hasInternetConnection] && ! [ZPFileDownloadManager isAttachmentDownloading:attachment]){
                [ZPFileDownloadManager checkIfCanBeDownloadedAndStartDownloadingAttachment:attachment];
                _latestManuallyTriggeredAttachment = attachment;
            }
            
        }
        
    }
}

- (void)carouselCurrentItemIndexUpdated:(iCarousel *)carousel{
    NSAssert(carousel==self.attachmentCarousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");

    // Prevent automatically opening an attachment if the active attachment has changed
    _latestManuallyTriggeredAttachment = NULL;
}

#pragma mark - Item observer methods

/*
 These are called by data layer to notify that more information about an item has become available from the server
 */

-(void) notifyItemsAvailable:(NSNotification*) notification{
    
    NSArray* items = notification.object;
    
    for(ZPZoteroItem* item in items){
        if([item.key isEqualToString:_item.key]){
            _item = item;
            _attachments = item.attachments;
            
            if([self.attachmentCarousel numberOfItems]!= _attachments.count){
                if([_attachments count]==0){
                    [self.attachmentCarousel setHidden:TRUE];
                }
                else{
                    [self.attachmentCarousel setHidden:FALSE];
                    [self.attachmentCarousel setScrollEnabled:[_attachments count]>1];
                    [self.attachmentCarousel performSelectorOnMainThread:@selector(reloadData) withObject:NULL waitUntilDone:NO];
                }
            }
        }
    }
}


-(void) _reloadAttachmentInCarousel:(ZPZoteroItem*)attachment {
    NSInteger index = [_attachments indexOfObject:attachment];
    if(index !=NSNotFound){
        [self performSelectorOnMainThread:@selector(_reloadCarouselItemAtIndex:) withObject:[NSNumber numberWithInt:index] waitUntilDone:YES];
    }
}

-(void) _reloadCarouselItemAtIndex:(NSInteger) index{
    [attachmentCarousel reloadItemAtIndex:index animated:YES];
}

#pragma mark - Attachment observer methods


-(void) notifyAttachmentDownloadCompleted:(NSNotification *) notification{

    ZPZoteroAttachment* attachment = notification.object;
    
    if(mode ==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD || 
       (ZPATTACHMENTICONGVIEWCONTROLLER_MODE_FIRST_STATIC_SECOND_DOWNLOAD && [_attachments indexOfObject:attachment]==2)){
        
        [self _setLabelsForAttachment:attachment progressText:NULL errorText:NULL mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC reconfigureIcon:TRUE];

        // If this is manually triggered, open it
        
        if(_latestManuallyTriggeredAttachment == attachment){
            _latestManuallyTriggeredAttachment = NULL;
            [ZPFileViewerViewController  presentWithAttachment:attachment];
        }

    }
}
-(void) notifyAttachmentDownloadFailed:(NSNotification *) notification{

    ZPZoteroAttachment* attachment = notification.object;

    if(mode ==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD ||
       (ZPATTACHMENTICONGVIEWCONTROLLER_MODE_FIRST_STATIC_SECOND_DOWNLOAD && [_attachments indexOfObject:attachment]==2)){
        [self _setLabelsForAttachment:attachment progressText:@"Download failed" errorText:[notification.userInfo objectForKey:NSLocalizedDescriptionKey] mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC reconfigureIcon:FALSE];
    }
}

-(void) notifyAttachmentDownloadStarted:(NSNotification *) notification{
    
    ZPZoteroAttachment* attachment = notification.object;

    if(mode ==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD ||
       (ZPATTACHMENTICONGVIEWCONTROLLER_MODE_FIRST_STATIC_SECOND_DOWNLOAD && [_attachments indexOfObject:attachment]==2)){
        [self _setLabelsForAttachment:attachment progressText:@"Downloading" errorText:NULL mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD reconfigureIcon:FALSE];    
    }
}

-(void) notifyAttachmentDeleted:(NSNotification *) notification{
    
    ZPZoteroAttachment* attachment = notification.object;

    [self _setLabelsForAttachment:attachment progressText:@"File deleted" errorText:NULL mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC reconfigureIcon:FALSE];

}

-(void) notifyAttachmentUploadCompleted:(NSNotification *) notification{
    
    ZPZoteroAttachment* attachment = notification.object;

    if(mode ==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD){
        [self _setLabelsForAttachment:attachment progressText:@"Upload completed" errorText:NULL mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC reconfigureIcon:FALSE];
    }
}

-(void) notifyAttachmentUploadFailed:(NSNotification *) notification{
    
    ZPZoteroAttachment* attachment = notification.object;
    
    if(mode ==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD){
        [self _setLabelsForAttachment:attachment progressText:@"Upload failed" errorText:[notification.userInfo objectForKey:NSLocalizedDescriptionKey] mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC reconfigureIcon:FALSE];
    }
}

-(void) notifyAttachmentUploadStarted:(NSNotification *) notification{
    
    ZPZoteroAttachment* attachment = notification.object;

    if(mode ==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD){
        [self _setLabelsForAttachment:attachment progressText:@"Uploading" errorText:NULL mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD reconfigureIcon:FALSE];
    }
}

// This is not in use, but implemented nevertheless

-(void) notifyAttachmentUploadCanceled:(NSNotification *) notification{
    
    ZPZoteroAttachment* attachment = notification.object;
    
    if(mode ==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD){
        [self _setLabelsForAttachment:attachment progressText:@"Upload canceled" errorText:NULL mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC reconfigureIcon:FALSE];
    }
}


-(void) _setLabelsForAttachment:(ZPZoteroAttachment*)attachment progressText:(NSString*)progressText errorText:(NSString*)errorText mode:(NSInteger)aMode reconfigureIcon:(BOOL)reconfigureIcon{
    NSInteger index = [_attachments indexOfObject:attachment];    
    
    if(index!=NSNotFound){

        UIView* view = [attachmentCarousel itemViewAtIndex:index];
        
        if(view != NULL){
            
            if ([NSThread isMainThread]){

                UILabel* progressLabel = (UILabel*)[view viewWithTag:ZPATTACHMENTICONGVIEWCONTROLLER_TAG_STATUSLABEL];
                if(progressText == NULL){
                    progressLabel.hidden = TRUE;   
                }
                else{
                    progressLabel.text = progressText;   
                    progressLabel.hidden = FALSE;
                }
                
                UILabel* errorLabel = (UILabel*)[view viewWithTag:ZPATTACHMENTICONGVIEWCONTROLLER_TAG_ERRORLABEL];
                if(errorText == NULL){
                    errorLabel.hidden = TRUE;   
                }
                else{
                    errorLabel.text = errorText;   
                    errorLabel.hidden = FALSE;
                }
                
                UIProgressView* progressView = (UIProgressView*)[view viewWithTag:ZPATTACHMENTICONGVIEWCONTROLLER_TAG_PROGRESSVIEW];
                if(aMode == ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC){
                    progressView.hidden = TRUE;
                    view.userInteractionEnabled = FALSE;
                }
                else if (aMode==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD){
                    progressView.hidden = FALSE;
                    progressView.progress = 0.0f;
                    [ZPFileUploadManager useProgressView:progressView forUploadingAttachment:attachment];
                    view.userInteractionEnabled = TRUE;
                }
                else if (aMode==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD){
                    progressView.hidden = FALSE;
                    progressView.progress = 0.0f;
                    [ZPFileDownloadManager useProgressView:progressView forDownloadingAttachment:attachment];
                    view.userInteractionEnabled = FALSE;
                }
                
                if(reconfigureIcon) [self _configureFileImageView:(UIImageView*)[view viewWithTag:ZPATTACHMENTICONGVIEWCONTROLLER_TAG_FILEIMAGE] withAttachment:attachment];


            }
            else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self _setLabelsForAttachment:attachment progressText:progressText errorText:errorText mode:mode reconfigureIcon:reconfigureIcon];
                });
            }
        }
    }
}

-(UIView*) sourceViewForQuickLook{
    
    
    //If we have had a low memory condition, it is possible that views are not loaded

    if(! [owner isViewLoaded]){
        [owner loadView];
        [owner viewDidLoad];
        [self.attachmentCarousel reloadData];
    }

    // Because the user interface orientation may have changed, we need to layout subviews

    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        UISplitViewController* root =  (UISplitViewController*) [UIApplication sharedApplication].delegate.window.rootViewController;
        [root viewWillAppear:NO];
        [root.view layoutSubviews];
        
        UIViewController* navigationController = (UIViewController*)[root.viewControllers lastObject];
        [navigationController viewWillAppear:NO];
        [navigationController.view layoutSubviews];
    }
    else {
        UINavigationController* root =  (UINavigationController*) [UIApplication sharedApplication].delegate.window.rootViewController;
        [root viewWillAppear:NO];
        [root.view layoutSubviews];
    }

        

        
/* 
        UIViewController* parent = owner.parentViewController;
        while(parent != NULL && ! [parent isViewLoaded]){
            [parent loadView];
            [parent viewDidLoad];
            parent = parent.parentViewController;
        }
 */
    
    
    
    
    UIView* sourceView = [self.attachmentCarousel currentItemView];
    UIView* temp = sourceView;
    
    while(temp != nil){
        temp = temp.superview;
    }
    
    UIViewController* tempVC = owner;
    
    while(tempVC != nil){
        temp = tempVC.view;
        tempVC = tempVC.parentViewController;
    }

    return sourceView;
}

@end
