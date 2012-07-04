//
//  ZPFileImportView.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 8.4.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPCore.h"

#import "ZPFileImportViewController.h"
#include <QuartzCore/QuartzCore.h>
#import "ZPDataLayer.h"
#import "ZPServerConnection.h"
#import "ZPCacheController.h"
#import "ZPAttachmentCarouselDelegate.h"
@interface ZPFileImportViewController (){
    ZPAttachmentCarouselDelegate* _carouselDelegate;
}


@end


@implementation ZPFileImportViewController

@synthesize url, carousel;

- (void)viewDidLoad
{
    [super viewDidLoad];
	_carouselDelegate = [[ZPAttachmentCarouselDelegate alloc] init];
    _carouselDelegate.mode = ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD;
    _carouselDelegate.show = ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_MODIFIED;
    _carouselDelegate.attachmentCarousel = carousel;
    ZPZoteroAttachment* attachment = [ZPZoteroAttachment dataObjectForAttachedFile:url.absoluteString];
    [_carouselDelegate configureWithAttachmentArray:[NSArray arrayWithObject:attachment]];
    carousel.dataSource = _carouselDelegate;
    carousel.delegate = self;
    
    [[ZPDataLayer instance] registerAttachmentObserver:_carouselDelegate];
}
- (void)viewWillAppear:(BOOL)animated{
    
    
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}
- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    [[ZPDataLayer instance] removeAttachmentObserver:_carouselDelegate];

}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)carousel:(iCarousel *)carousel didSelectItemAtIndex:(NSInteger)index{
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - Alert view delegate methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    [self dismissModalViewControllerAnimated:YES];
}

@end
