//
//  ZPUploadVersionConflictViewControllerViewController.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 27.6.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPUploadVersionConflictViewControllerViewController.h"

#import "ZPAttachmentIconImageFactory.h"
#import "ZPFileCacheManager.h"

// A helper class for showing an original version of the attachment


@interface ZPUploadVersionConflictViewControllerViewController ()

@end

@implementation ZPUploadVersionConflictViewControllerViewController

@synthesize attachment, label, carousel, fileChannel,secondaryCarousel;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.

}

-(void)viewWillAppear:(BOOL)animated{

    [super viewWillAppear:animated];
    
    if(_carouselDelegate == NULL){
        _carouselDelegate = [[ZPAttachmentCarouselDelegate alloc] init];
        _carouselDelegate.owner = self;
        
        //iPhone shows the versions in carousel. On iPad they are shown in separate carousels
        
        if(secondaryCarousel==NULL){
            [_carouselDelegate configureWithAttachmentArray:[NSArray arrayWithObjects:attachment, attachment, nil]];
            _carouselDelegate.mode = ZPATTACHMENTICONGVIEWCONTROLLER_MODE_FIRST_STATIC_SECOND_DOWNLOAD;
            _carouselDelegate.show = ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_FIRST_MODIFIED_SECOND_ORIGINAL;
            carousel.type = iCarouselTypeCoverFlow2;
            carousel.bounces = FALSE;
            
        }
        else{
            [_carouselDelegate configureWithAttachmentArray:[NSArray arrayWithObject:attachment]];
            _carouselDelegate.mode = ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC;
            _carouselDelegate.show = ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_MODIFIED;
        }
        _carouselDelegate.attachmentCarousel = carousel;
        carousel.delegate = _carouselDelegate;
        carousel.dataSource = _carouselDelegate;
        
        carousel.currentItemIndex = 0;
        
        
        if(secondaryCarousel!=NULL){
            _secondaryCarouselDelegate = [[ZPAttachmentCarouselDelegate alloc] init];
            _secondaryCarouselDelegate.owner = self;
            _secondaryCarouselDelegate.mode = ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD;
            _secondaryCarouselDelegate.show = ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_ORIGINAL;
            [_secondaryCarouselDelegate configureWithAttachmentArray:[NSArray arrayWithObject: attachment]];
            _secondaryCarouselDelegate.attachmentCarousel = secondaryCarousel;
            secondaryCarousel.delegate = _secondaryCarouselDelegate;
            secondaryCarousel.dataSource = _secondaryCarouselDelegate;
            secondaryCarousel.currentItemIndex = 0;
        }
    }    
    
    label.text = [NSString stringWithFormat:@"File '%@' has changed on server",attachment.filenameBasedOnLinkMode];
}

-(void) dealloc{
    [_carouselDelegate unregisterProgressViewsBeforeUnloading];
    if(_secondaryCarouselDelegate != NULL){
        [_secondaryCarouselDelegate unregisterProgressViewsBeforeUnloading];
    }
}
- (void) viewWillUnload{
    [super viewWillUnload];
    [_carouselDelegate unregisterProgressViewsBeforeUnloading];
    if(_secondaryCarouselDelegate != NULL){
        [_secondaryCarouselDelegate unregisterProgressViewsBeforeUnloading];
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark - Actions

-(IBAction)useMyVersion:(id)sender{
    [ZPDatabase writeVersionInfoForAttachment:attachment];
    if([attachment fileExists_modified]){
        [fileChannel startUploadingAttachment:attachment overWriteConflictingServerVersion:YES];
        [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_STARTED object:attachment];
    }
    else{
        DDLogError(@"Attempting to upload non-existng file %@", attachment.filenameBasedOnLinkMode);
    }
    [self dismissModalViewControllerAnimated:YES];

}
-(IBAction)useRemoteVersion:(id)sender{
    attachment.versionIdentifier_local = NULL;
    [ZPFileCacheManager deleteModifiedFileForAttachment:attachment reason:@"User chose server file during conflict"];
    [ZPDatabase writeVersionInfoForAttachment:attachment];
    [fileChannel cancelUploadingAttachment:attachment];
    [self dismissModalViewControllerAnimated:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_CANCELED object:attachment];
}


@end
