//
//  ZPAttachmentCarouselDelegate.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 25.6.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "iCarousel.h"
#import "ZPCore.h"

@interface ZPAttachmentCarouselDelegate : NSObject <iCarouselDelegate, iCarouselDataSource, ZPAttachmentObserver, ZPItemObserver>{
    ZPZoteroItem* _item;
    NSArray* _attachments;
}

@property (retain) IBOutlet UIBarButtonItem* actionButton;
@property (retain) IBOutlet iCarousel* attachmentCarousel;
@property (assign) NSInteger mode;
@property (assign) NSInteger show;

-(void) configureWithAttachmentArray:(NSArray*) attachments;
-(void) configureWithZoteroItem:(ZPZoteroItem*) item;

@end
