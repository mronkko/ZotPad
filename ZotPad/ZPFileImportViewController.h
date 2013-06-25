//
//  ZPFileImportView.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 8.4.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "iCarousel.h"
#import "ZPCore.h"
#import "ZPModalViewController.h"

@interface ZPFileImportViewController : ZPModalViewController <iCarouselDelegate>{
}

@property (retain, nonatomic) IBOutlet iCarousel* carousel;
@property (retain, nonatomic) ZPZoteroAttachment* attachment;

+(void) presentInstanceModallyWithAttachment:(ZPZoteroAttachment*) attachment;

@end
