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


@interface ZPAttachmentIconViewController : UIViewController <ZPAttachmentObserver, UIWebViewDelegate, UIGestureRecognizerDelegate>{
}


@property (nonatomic, retain) IBOutlet UILabel* titleLabel;
@property (nonatomic, retain) IBOutlet UILabel* downloadLabel;
@property (nonatomic, retain) IBOutlet UILabel* errorLabel;
@property (nonatomic, retain) IBOutlet UIView* labelBackground;
@property (nonatomic, retain) IBOutlet UIImageView* fileImage;
@property (nonatomic, retain) IBOutlet UIProgressView* progressView;
@property (nonatomic, retain) IBOutlet UIButton* cancelButton;
@property (nonatomic, retain) ZPZoteroAttachment* attachment;
@property BOOL allowDownloading;
@property BOOL usePreview;
@property BOOL showLabel;

+(void) renderFileTypeIconForAttachment:(ZPZoteroAttachment*) attachment intoImageView:(UIImageView*) fileImage;


@end
