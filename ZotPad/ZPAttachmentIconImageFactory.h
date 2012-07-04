//
//  ZPAttachmentPreviewViewController.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 17.4.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZPZoteroAttachment.h"
#import "ZPAttachmentObserver.h"




@interface ZPAttachmentIconImageFactory : NSObject <UIWebViewDelegate>{
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
+(void) renderPDFPreviewForFileAtPath:(NSString*) filePath intoImageView:(UIImageView*) fileImage;
+(CGRect) getDimensionsForImageView:(UIImageView*) imageView withImage:(UIImage*) image;    


@end
