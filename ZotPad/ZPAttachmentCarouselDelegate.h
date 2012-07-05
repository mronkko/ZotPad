//
//  ZPAttachmentCarouselDelegate.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 25.6.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "iCarousel.h"
#import "ZPCore.h"

extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_FIRST_STATIC_SECOND_DOWNLOAD;

extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_ORIGINAL;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_MODIFIED;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_FIRST_MODIFIED_SECOND_ORIGINAL;


extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_TAG_FILEIMAGE;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_TAG_ERRORLABEL;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_TAG_STATUSLABEL;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_TAG_PROGRESSVIEW;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_TAG_TITLELABEL;

@interface ZPAttachmentCarouselDelegate : NSObject <iCarouselDelegate, iCarouselDataSource, ZPAttachmentObserver, ZPItemObserver>{
    ZPZoteroItem* _item;
    NSArray* _attachments;
}

@property (weak) IBOutlet UIBarButtonItem* actionButton;
@property (weak) IBOutlet iCarousel* attachmentCarousel;
@property (assign) NSInteger mode;
@property (assign) NSInteger show;

-(void) configureWithAttachmentArray:(NSArray*) attachments;
-(void) configureWithZoteroItem:(ZPZoteroItem*) item;
+(void) renderFileTypeIconForAttachment:(ZPZoteroAttachment*) attachment intoImageView:(UIImageView*) fileImage;

@end
