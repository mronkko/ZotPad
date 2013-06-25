//
//  ZPFileImportView.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 8.4.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPFileImportViewController.h"
#import "ZPAttachmentCarouselDelegate.h"

@interface ZPFileImportViewController (){
    ZPAttachmentCarouselDelegate* _carouselDelegate;
    ZPZoteroAttachment* _attachment;
}

-(void) _configureWithAttachment:(ZPZoteroAttachment*) attachment;

@end


@implementation ZPFileImportViewController

@synthesize carousel;



+(void) presentInstanceModallyWithAttachment:(ZPZoteroAttachment*) attachment{
    
    if([NSThread isMainThread]){
        ZPFileImportViewController* instance = (ZPFileImportViewController*)[self instance];
        instance.attachment = attachment;
        [instance presentModally:FALSE];
    }
    else{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentInstanceModallyWithAttachment:attachment];
        });
    }

}

-(void) _configureWithAttachment:(ZPZoteroAttachment*) attachment{
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];

    //The carousel needs to be configured here so that we know the dimensions
    
    if(_carouselDelegate == NULL){
        _carouselDelegate = [[ZPAttachmentCarouselDelegate alloc] init];
        _carouselDelegate.owner = self;
        _carouselDelegate.mode = ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD;
        _carouselDelegate.show = ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_MODIFIED;
        _carouselDelegate.attachmentCarousel = carousel;
        [_carouselDelegate configureWithAttachmentArray:[NSArray arrayWithObject:self.attachment]];
        carousel.dataSource = _carouselDelegate;
        carousel.delegate = self;
    }
    
}
- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}
- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
}

-(void) dealloc{
    [_carouselDelegate unregisterProgressViewsBeforeUnloading];
}
- (void) viewWillUnload{
    [super viewWillUnload];
    [_carouselDelegate unregisterProgressViewsBeforeUnloading];
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

- (void)carousel:(iCarousel *)carousel didSelectItemAtIndex:(NSInteger)index{
    [self dismissModalViewControllerAnimated:YES];
}

@end
