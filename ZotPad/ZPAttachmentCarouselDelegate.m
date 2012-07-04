//
//  ZPAttachmentCarouselDelegate.m
//  ZotPad
//
//  This class assumes that there is only one carousel that it serves
//
//
//  Created by Mikko Rönkkö on 25.6.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPAttachmentCarouselDelegate.h"
#import "ZPPreviewController.h"
#import "ZPServerConnection.h"
#import "ZPDataLayer.h"
#import "ZPAttachmentIconImageFactory.h"
#import <QuartzCore/QuartzCore.h>
#import <zlib.h>


NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC = 0;
NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD = 1;
NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD = 2;
NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_FIRST_STATIC_SECOND_DOWNLOAD = 3;

NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_ORIGINAL = 10;
NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_MODIFIED = 11;
NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_FIRST_MODIFIED_SECOND_ORIGINAL = 12;

@interface ZPAttachmentCarouselDelegate()

-(void) _toggleActionButtonState;
-(BOOL) _fileExistsForAttachment:(ZPZoteroAttachment*) attachment;
-(void) _configureFileImageView:(UIImageView*) imageView withAttachment:(ZPZoteroAttachment*)attachment;
-(void) _configureProgressLabel:(UILabel*) label withAttachment:(ZPZoteroAttachment*)attachment;
-(NSInteger) _modeForAttachment:(ZPZoteroAttachment*)attachment;
-(NSInteger) _showForAttachment:(ZPZoteroAttachment*)attachment;
-(void) _setLabelsForAttachment:(ZPZoteroAttachment*)attachment progressText:(NSString*)progressText errorText:(NSString*)errorText mode:(NSInteger)mode;

@end


@implementation ZPAttachmentCarouselDelegate

@synthesize actionButton, attachmentCarousel, mode, show;

-(id) init{
    self = [super init];

    //Register self as observer for item downloads
    [[ZPDataLayer instance] registerAttachmentObserver:self];
    [[ZPDataLayer instance] registerItemObserver:self];

    return self;
}

-(void) dealloc{
    [[ZPDataLayer instance] removeItemObserver:self];
    [[ZPDataLayer instance] removeAttachmentObserver:self];
}

-(void) configureWithAttachmentArray:(NSArray*) attachments{
    _item = NULL;
    _attachments = attachments;
}
-(void) configureWithZoteroItem:(ZPZoteroItem*) item{
    _item = item;
    _attachments = item.attachments;
}

/*
 
 Checks if the currently selected attachment has a file and enables or disables the activity buttone
 
 */


- (void) _toggleActionButtonState{
    if(actionButton != NULL){
        if([_attachments count]==0){
            self.actionButton.enabled = FALSE;
        }
        else{
            NSInteger currentIndex = attachmentCarousel.currentItemIndex;
            // Initially the iCarousel can return a negative index. This is probably a bug.
            ZPZoteroAttachment* attachment = [_attachments objectAtIndex:currentIndex];
            self.actionButton.enabled = [self _fileExistsForAttachment:attachment]  &! [attachment.contentType isEqualToString:@"text/html"];
        }
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
        fileImage.tag = 1;
        [view addSubview:fileImage];
        
        NSInteger labelHeight = height*2/5;
        NSInteger labelWidth = width*4/5;
        
        UIView* labelBackground = [[UIView alloc] initWithFrame:CGRectMake((width-labelWidth)/2, (height-labelHeight)/2, labelWidth, labelHeight)];
        labelBackground.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:.5];
        labelBackground.layer.cornerRadius = 8;
        labelBackground.tag = 2;
        [view addSubview:labelBackground];
        
        NSInteger labelSubviewOffset = 10;
        NSInteger labelSubviewWidth = labelWidth-2*labelSubviewOffset; 
        NSInteger labelSubviewHeight = labelHeight-2*labelSubviewOffset;

        titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(labelSubviewOffset, labelSubviewOffset, labelSubviewWidth, labelSubviewHeight*.6)];
        titleLabel.numberOfLines = 4;
        titleLabel.tag = 3;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textColor = [UIColor whiteColor];
        
        [labelBackground addSubview:titleLabel];
        
        progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(labelSubviewOffset, labelSubviewOffset + labelSubviewHeight*.6, labelSubviewWidth, labelSubviewHeight*.15)];
        progressLabel.tag = 4;
        progressLabel.backgroundColor = [UIColor clearColor];
        progressLabel.textColor = [UIColor whiteColor];

        [labelBackground addSubview: progressLabel];
        
        progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(labelSubviewOffset, labelSubviewOffset + labelSubviewHeight*.75, labelSubviewWidth, labelSubviewHeight*.15)];
        progressView.tag = 5;
        progressView.backgroundColor = [UIColor clearColor];
        
        [labelBackground addSubview: progressView];
        
        errorLabel = [[UILabel alloc] initWithFrame:CGRectMake(labelSubviewOffset, labelSubviewOffset + labelSubviewHeight*.75, labelSubviewWidth, labelSubviewHeight*.25)];
        errorLabel.tag = 6;
        errorLabel.backgroundColor = [UIColor clearColor];
        errorLabel.textColor = [UIColor whiteColor];
        
        [labelBackground addSubview:errorLabel];
        
        
    }
    else{
        
        fileImage = (UIImageView*)[view viewWithTag:1];
        UIView* labelBackground = [view viewWithTag:2];
        titleLabel = (UILabel*)[labelBackground viewWithTag:3];
        progressLabel = (UILabel*)[labelBackground viewWithTag:4];
        progressView = (UIProgressView*)[labelBackground viewWithTag:5];
        errorLabel = (UILabel*)[labelBackground viewWithTag:6];
    }


    [self _configureFileImageView:fileImage withAttachment:attachment];
    [self _configureProgressLabel:progressLabel withAttachment:attachment];

    titleLabel.text = attachment.title;
    errorLabel.hidden = TRUE;
    
    //TODO: Recycle progressviews better using notifications
    progressView.hidden=TRUE;
    
    //Set the status
    //TODO: Refactor: This is not the right place for this call
    [self _toggleActionButtonState];
    
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

    UIImage* image = NULL;
    
    if(attachment.fileExists && [attachment.contentType isEqualToString:@"application/pdf"]){
        
        NSString* path;
        if([self _showForAttachment:attachment] == ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_ORIGINAL){
            path =attachment.fileSystemPath_original;
        }
        else{
            path =attachment.fileSystemPath;    
        }
        
        
        [ZPAttachmentIconImageFactory renderPDFPreviewForFileAtPath:path intoImageView:imageView];
        
    }
    
    if(image == NULL){
        [ZPAttachmentIconImageFactory renderFileTypeIconForAttachment:attachment intoImageView:imageView];
    }
    else{
        CGRect frame = [ZPAttachmentIconImageFactory getDimensionsForImageView:imageView withImage:image];
        imageView.layer.frame = frame;
        imageView.center = imageView.superview.center;
        imageView.layer.borderWidth = 2.0f;
        imageView.layer.borderColor = [UIColor blackColor].CGColor;
        [imageView setBackgroundColor:[UIColor whiteColor]]; 
        
        imageView.image=image;
        
        //Set the old bacground transparent
        imageView.superview.layer.borderColor = [UIColor clearColor].CGColor;
        imageView.superview.backgroundColor = [UIColor clearColor];    
    }
}


-(void) _configureProgressLabel:(UILabel*) label withAttachment:(ZPZoteroAttachment*)attachment{

    NSInteger thisMode = [self _modeForAttachment:attachment];
    NSInteger thisShow = [self _showForAttachment:attachment];
                          
    if(thisMode == ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD){

        if([[ZPServerConnection instance] isAttachmentDownloading:attachment]){
            [self notifyAttachmentDownloadStarted:attachment];
        }
        else{
            
            //Imported files and URLs have files that can be downloaded
            
            NSInteger linkMode = [attachment.linkMode intValue ];
            BOOL exists;
            if(thisShow == ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_ORIGINAL){
                exists = [attachment fileExists_original];
            }
            else{
                exists = [attachment fileExists];
            }
            if((linkMode == LINK_MODE_IMPORTED_FILE || linkMode == LINK_MODE_IMPORTED_URL )
               && ! exists){
                                
                if([[ZPPreferences instance] online]){
                    
                    //TODO: Check if already downloading.
                    
                    if ([[ZPPreferences instance] useDropbox]) label.text = @"Download from Dropbox";
                    else if([[ZPPreferences instance] useWebDAV] && [attachment.libraryID intValue] == 1) label.text = @"Download from WebDAV";
                    else if ([attachment.existsOnZoteroServer intValue]==1){
                        if(attachment.attachmentSize!= NULL && attachment.attachmentSize != [NSNull null]){
                            NSInteger size = [attachment.attachmentSize intValue];
                            label.text =  [NSString stringWithFormat:@"Download from Zotero (%i KB)",size/1024];
                        }
                        else{
                            label.text = @"Download from Zotero";
                        }
                    }
                    else label.text = @"File cannot be found for download";
                }
                else  label.text = @"File cannot be downloaded when offline";
            }
            
            // Linked URL will be shown directly from web 
            
            else if ([attachment.linkMode intValue] == LINK_MODE_LINKED_URL &&
                     !  [[ZPPreferences instance] online]){
                label.text = @"Linked URL cannot be viewed in offline mode";
                
            }
            
            //Linked files are available only on the computer where they were created
            
            else if ([attachment.linkMode intValue] == LINK_MODE_LINKED_FILE) {
                label.text = @"Linked files cannot be viewed in ZotPad";
            }
            
            else{
                label.hidden = TRUE;
            }
        }    
    }
    
    
    
    
    
    else if(self.mode == ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD){
        label.hidden = FALSE;
        
        if([[ZPServerConnection instance] isAttachmentDownloading:attachment]){
            [self notifyAttachmentDownloadStarted:attachment];
        }
        else{
            label.text = @"Waiting for upload";
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
        
        if([self _fileExistsForAttachment:attachment] ||
           ([attachment.linkMode intValue] == LINK_MODE_LINKED_URL && [ZPServerConnection instance])){
            UIView* sourceView;
            for(sourceView in carousel.visibleItemViews){
                if([carousel indexOfItemView:sourceView] == index) break;
            }
            
            [ZPPreviewController displayQuicklookWithAttachment:attachment sourceView:sourceView];
        }
        else if(self.mode == ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD && ( [attachment.linkMode intValue] == LINK_MODE_IMPORTED_FILE || 
                [attachment.linkMode intValue] == LINK_MODE_IMPORTED_URL)){
            
            ZPServerConnection* connection = [ZPServerConnection instance];
            
            
            if(connection!=NULL && ! [connection isAttachmentDownloading:attachment]){
                [connection checkIfCanBeDownloadedAndStartDownloadingAttachment:attachment];   
            }
            
        }
        
    }
}

- (void)carouselCurrentItemIndexUpdated:(iCarousel *)carousel{
    NSAssert(carousel==self.attachmentCarousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");
    
    if(actionButton != NULL){
        if([_attachments count]==0){
            actionButton.enabled = FALSE;
        }
        else{
            NSInteger currentIndex = carousel.currentItemIndex;
            // Initially the iCarousel can return a negative index. This is probably a bug in iCarousel.
            if(currentIndex <0) currentIndex = 0;
            ZPZoteroAttachment* attachment = [_attachments objectAtIndex:currentIndex];
            actionButton.enabled = [self _fileExistsForAttachment:attachment] &! [attachment.contentType isEqualToString:@"text/html"];
        }
    }
}


#pragma mark - Item observer methods

/*
 These are called by data layer to notify that more information about an item has become available from the server
 */

-(void) notifyItemAvailable:(ZPZoteroItem*) item{
    
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


-(void) _reloadAttachmentInCarousel:(ZPZoteroItem*)attachment {
    NSInteger index = [_attachments indexOfObject:attachment];
    if(index !=NSNotFound){
        [self performSelectorOnMainThread:@selector(_reloadCarouselItemAtIndex:) withObject:[NSNumber numberWithInt:index] waitUntilDone:YES];
        [self _toggleActionButtonState];
    }
}

-(void) _reloadCarouselItemAtIndex:(NSInteger) index{
    [attachmentCarousel reloadItemAtIndex:index animated:YES];
}

#pragma mark - Attachment observer methods


-(void) notifyAttachmentDownloadCompleted:(ZPZoteroAttachment*) attachment{

    if(mode ==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD || 
       (ZPATTACHMENTICONGVIEWCONTROLLER_MODE_FIRST_STATIC_SECOND_DOWNLOAD && [_attachments indexOfObject:attachment]==2)){
        
        [self _toggleActionButtonState];
        [self _setLabelsForAttachment:attachment progressText:NULL errorText:NULL mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC];
    }
}
-(void) notifyAttachmentDownloadFailed:(ZPZoteroAttachment *)attachment withError:(NSError *)error{
    
    if(mode ==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD || 
       (ZPATTACHMENTICONGVIEWCONTROLLER_MODE_FIRST_STATIC_SECOND_DOWNLOAD && [_attachments indexOfObject:attachment]==2)){
        [self _setLabelsForAttachment:attachment progressText:@"Download failed" errorText:[error localizedDescription] mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC];    
    }
}

-(void) notifyAttachmentDownloadStarted:(ZPZoteroAttachment*) attachment{
    if(mode ==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD || 
       (ZPATTACHMENTICONGVIEWCONTROLLER_MODE_FIRST_STATIC_SECOND_DOWNLOAD && [_attachments indexOfObject:attachment]==2)){
        [self _setLabelsForAttachment:attachment progressText:@"Downloading" errorText:NULL mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD];    
    }
}

-(void) notifyAttachmentDeleted:(ZPZoteroAttachment*) attachment fileAttributes:(NSDictionary*) fileAttributes{
    
    [self _toggleActionButtonState];
    [self _setLabelsForAttachment:attachment progressText:@"File deleted" errorText:NULL mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC];

}

-(void) notifyAttachmentUploadCompleted:(ZPZoteroAttachment*) attachment{
    if(mode ==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD){
        [self _setLabelsForAttachment:attachment progressText:@"Upload completed" errorText:NULL mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC];
    }
}

-(void) notifyAttachmentUploadFailed:(ZPZoteroAttachment*) attachment withError:(NSError*) error{
    if(mode ==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD){
        [self _setLabelsForAttachment:attachment progressText:@"Upload failed" errorText:[error localizedDescription] mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC];
    }
}

-(void) notifyAttachmentUploadStarted:(ZPZoteroAttachment*) attachment{
    if(mode ==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD){
        [self _setLabelsForAttachment:attachment progressText:@"Uploading" errorText:NULL mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD];
    }
}

-(void) notifyAttachmentUploadCanceled:(ZPZoteroAttachment*) attachment{
    if(mode ==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD){
        [self _setLabelsForAttachment:attachment progressText:@"Upload canceled" errorText:NULL mode:ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC];
    }
}

-(void) _setLabelsForAttachment:(ZPZoteroAttachment*)attachment progressText:(NSString*)progressText errorText:(NSString*)errorText mode:(NSInteger)mode{
    NSInteger index = [_attachments indexOfObject:attachment];    
    
    if(index!=NSNotFound){

        UIView* view = [attachmentCarousel itemViewAtIndex:index];
        
        if(view != NULL){
            
            if ([NSThread isMainThread]){

                UIView* labelBackground = [view viewWithTag:2];
                
                UILabel* progressLabel = (UILabel*)[labelBackground viewWithTag:4];
                if(progressText == NULL) progressLabel.hidden = TRUE;
                else progressLabel.text = progressText;
                
                UILabel* errorLabel = (UILabel*)[labelBackground viewWithTag:6];
                if(errorText == NULL) errorLabel.hidden = TRUE;
                else errorLabel.text = errorText;
                
                UIProgressView* progressView = (UIProgressView*)[labelBackground viewWithTag:5];
                if(mode == ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC){
                    progressView.hidden = TRUE;
                    view.userInteractionEnabled = FALSE;
                }
                else if (mode==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD){
                    progressView.hidden = FALSE;
                    [[ZPServerConnection instance] useProgressView:progressView forUploadingAttachment:attachment];
                    view.userInteractionEnabled = TRUE;
                }
                else if (mode==ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD){
                    progressView.hidden = FALSE;
                    [[ZPServerConnection instance] useProgressView:progressView forDownloadingAttachment:attachment];
                    view.userInteractionEnabled = FALSE;
                }

            }
            else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self _setLabelsForAttachment:attachment progressText:progressText errorText:errorText mode:mode];
                });
            }
        }
    }
}


@end
