//
//  ZPFileImportView.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 8.4.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "iCarousel.h"

@interface ZPFileImportViewController : UIViewController <iCarouselDelegate>{
}

@property BOOL isFullyPresented;

@property (retain) IBOutlet iCarousel* carousel;
@property (retain) NSURL* url;

@end
