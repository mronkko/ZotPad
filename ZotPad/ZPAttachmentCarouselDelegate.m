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
#import "ZPAttachmentIconViewController.h"
#import "ZPPreviewController.h"
#import "ZPServerConnection.h"


@interface ZPAttachmentCarouselDelegate()

-(void) _toggleActionButtonState;

@end


@implementation ZPAttachmentCarouselDelegate

@synthesize actionButton, carousel, mode, show;

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
            NSInteger currentIndex = carousel.currentItemIndex;
            // Initially the iCarousel can return a negative index. This is probably a bug.
            if(currentIndex <0) currentIndex = 0;
            ZPZoteroAttachment* attachment = [_attachments objectAtIndex:currentIndex];
            self.actionButton.enabled = attachment.fileExists &! [attachment.contentType isEqualToString:@"text/html"];
        }
    }
}

#pragma mark - iCarousel delegate


- (NSUInteger)numberOfPlaceholdersInCarousel:(iCarousel *)carousel{
    NSAssert(carousel==self.carousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");
    return 0;
}

- (NSUInteger)numberOfItemsInCarousel:(iCarousel *)carousel
{
    NSAssert(carousel==self.carousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");
    return [_attachments count];
}


- (NSUInteger) numberOfVisibleItemsInCarousel:(iCarousel*)carousel{
    NSAssert(carousel==self.carousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");
    NSInteger numItems = [self numberOfItemsInCarousel:carousel];
    NSInteger ret=  MAX(numItems,5);
    return ret;
}

- (UIView *)carousel:(iCarousel *)carousel viewForItemAtIndex:(NSUInteger)index reusingView:(UIView*)view
{
    NSAssert(carousel==self.carousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");
    ZPAttachmentIconViewController* attachmentViewController;
    
    if(view==NULL){
        UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;
        UIStoryboard *storyboard = root.storyboard;
        attachmentViewController = [storyboard instantiateViewControllerWithIdentifier:@"AttachmentPreview"];
    }
    else{
        attachmentViewController = (ZPAttachmentIconViewController*) [view nextResponder];
    }
    
    attachmentViewController.attachment= [_attachments objectAtIndex:index];
   
    
    if(mode == ZPATTACHMENTICONGVIEWCONTROLLER_MODE_FIRST_STATIC_SECOND_DOWNLOAD && index == 0){
        attachmentViewController.mode = ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC;
    }
    if(mode == ZPATTACHMENTICONGVIEWCONTROLLER_MODE_FIRST_STATIC_SECOND_DOWNLOAD && index == 1){
        attachmentViewController.mode = ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD;
    }
    else {
        attachmentViewController.mode = self.mode;
    }
    
    
    if(show == ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_FIRST_MODIFIED_SECOND_ORIGINAL && index == 0){
        attachmentViewController.mode = ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_ORIGINAL;
    }
    if(show == ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_FIRST_MODIFIED_SECOND_ORIGINAL && index == 1){
        attachmentViewController.show = ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_MODIFIED;
    }
    else {
        attachmentViewController.show = self.show;
    }
    
    //Set the status
    [self _toggleActionButtonState];
    
    view = attachmentViewController.view;
    
    //Scale if needed
    
    float scalingFactor = MIN(carousel.frame.size.height/view.frame.size.height,carousel.frame.size.width/view.frame.size.width);

    if(scalingFactor<1){
        view.frame = CGRectMake(0,0,view.frame.size.width*scalingFactor, view.frame.size.height*scalingFactor);
    }
    return view;
}

//This is implemented because it is a mandatory protocol method
- (UIView *)carousel:(iCarousel *)carousel placeholderViewAtIndex:(NSUInteger)index reusingView:(UIView *)view{
    NSAssert(carousel==self.carousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");
    return view;
}

- (void)carousel:(iCarousel *)carousel didSelectItemAtIndex:(NSInteger)index{
    NSAssert(carousel==self.carousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");
    if([carousel currentItemIndex] == index){
        
        ZPZoteroAttachment* attachment = [_attachments objectAtIndex:index]; 
        
        if([attachment fileExists] ||
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
                DDLogVerbose(@"Started downloading file %@ in index %i",attachment.title,index);
                [connection checkIfCanBeDownloadedAndStartDownloadingAttachment:attachment];   
            }
            
        }
        
    }
}

- (void)carouselCurrentItemIndexUpdated:(iCarousel *)carousel{
    NSAssert(carousel==self.carousel,@"ZPAttachmentCarouselDelegate can only be used with the iCarousel set in the carousel property");
    
    if(actionButton != NULL){
        if([_attachments count]==0){
            actionButton.enabled = FALSE;
        }
        else{
            NSInteger currentIndex = carousel.currentItemIndex;
            // Initially the iCarousel can return a negative index. This is probably a bug in iCarousel.
            if(currentIndex <0) currentIndex = 0;
            ZPZoteroAttachment* attachment = [_attachments objectAtIndex:currentIndex];
            actionButton.enabled = attachment.fileExists &! [attachment.contentType isEqualToString:@"text/html"];
        }
    }
}


#pragma mark - Observer methods

/*
 These are called by data layer to notify that more information about an item has become available from the server
 */

-(void) notifyItemAvailable:(ZPZoteroItem*) item{
    
    if([item.key isEqualToString:_item.key]){
        _item = item;
        _attachments = item.attachments;
        
        if([carousel numberOfItems]!= _attachments.count){
            if([_attachments count]==0){
                [carousel setHidden:TRUE];
            }
            else{
                [carousel setHidden:FALSE];
                [carousel setScrollEnabled:[_attachments count]>1];
                [carousel performSelectorOnMainThread:@selector(reloadData) withObject:NULL waitUntilDone:NO];
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
    [carousel reloadItemAtIndex:index animated:YES];
}

-(void) notifyAttachmentDownloadCompleted:(ZPZoteroAttachment*) attachment{
    //Check if this had an effect on our currently displayed item
    [self _toggleActionButtonState];
}

-(void) notifyAttachmentDownloadFailed:(ZPZoteroAttachment*) attachment withError:(NSError*) error{}

-(void) notifyAttachmentDownloadStarted:(ZPZoteroAttachment*) attachment{}

@end
