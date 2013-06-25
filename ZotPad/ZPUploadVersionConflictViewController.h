//
//  ZPUploadVersionConflictViewControllerViewController.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 27.6.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "iCarousel.h"
#import "ZPAttachmentCarouselDelegate.h"
#import "ZPCore.h"
#import "ZPFileChannel.h"
#import "ZPModalViewController.h"


@interface ZPUploadVersionConflictViewController : ZPModalViewController{
    ZPAttachmentCarouselDelegate* _carouselDelegate;
    ZPAttachmentCarouselDelegate* _secondaryCarouselDelegate;
}

@property (retain) IBOutlet UILabel* label;
@property (retain) IBOutlet iCarousel* carousel;
@property (retain) IBOutlet iCarousel* secondaryCarousel;
@property (retain) ZPZoteroAttachment* attachment;

+(void) presentInstanceModallyWithAttachment:(ZPZoteroAttachment*) attachment;

-(IBAction)useMyVersion:(id)sender;
-(IBAction)useRemoteVersion:(id)sender;

@end
