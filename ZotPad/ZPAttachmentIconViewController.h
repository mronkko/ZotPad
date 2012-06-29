//
//  ZPAttachmentPreviewViewController.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 17.4.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZPZoteroAttachment.h"
#import "ZPAttachmentObserver.h"

extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_UPLOAD;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_DOWNLOAD;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_STATIC;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_MODE_FIRST_STATIC_SECOND_DOWNLOAD;

extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_ORIGINAL;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_MODIFIED;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_ORIGINAL_OR_MODIFIED;
extern NSInteger const ZPATTACHMENTICONGVIEWCONTROLLER_SHOW_FIRST_MODIFIED_SECOND_ORIGINAL;


@interface ZPAttachmentIconViewController : UIViewController <ZPAttachmentObserver, UIWebViewDelegate, UIGestureRecognizerDelegate>{
}


@property (nonatomic, retain) IBOutlet UILabel* titleLabel;
@property (nonatomic, retain) IBOutlet UILabel* progressLabel;
@property (nonatomic, retain) IBOutlet UILabel* errorLabel;
@property (nonatomic, retain) IBOutlet UIView* labelBackground;
@property (nonatomic, retain) IBOutlet UIImageView* fileImage;
@property (nonatomic, retain) IBOutlet UIProgressView* progressView;
@property (nonatomic, retain) IBOutlet UIButton* cancelButton;
@property (nonatomic, retain) ZPZoteroAttachment* attachment;
@property NSInteger mode;
@property NSInteger show;

+(void) renderFileTypeIconForAttachment:(ZPZoteroAttachment*) attachment intoImageView:(UIImageView*) fileImage;


@end
