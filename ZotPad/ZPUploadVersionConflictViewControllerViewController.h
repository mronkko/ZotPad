//
//  ZPUploadVersionConflictViewControllerViewController.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 27.6.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "iCarousel.h"
#import "ZPAttachmentCarouselDelegate.h"
#import "ZPCore.h"
#import "ZPFileChannel.h"


@interface ZPUploadVersionConflictViewControllerViewController : UIViewController{
    ZPAttachmentCarouselDelegate* _carouselDelegate;
    ZPAttachmentCarouselDelegate* _secondaryCarouselDelegate;
}

@property (retain) IBOutlet UILabel* label;
@property (retain) IBOutlet iCarousel* carousel;
@property (retain) IBOutlet iCarousel* secondaryCarousel;
@property (retain) ZPZoteroAttachment* attachment;
@property (retain) ZPFileChannel* fileChannel;

-(IBAction)useMyVersion:(id)sender;
-(IBAction)useRemoteVersion:(id)sender;

@end
