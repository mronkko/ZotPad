//
//  ZPItemDetailViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/4/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//


#import <UIKit/UIKit.h>
#import "ZPZoteroItem.h"
#import "ZPAttachmentObserver.h"
#import "iCarousel.h"
#import "ZPQuicklookController.h"
#import "ZPItemObserver.h"

@interface ZPItemDetailViewController : UITableViewController <iCarouselDataSource,
    iCarouselDelegate, ZPItemObserver, ZPAttachmentObserver, UINavigationControllerDelegate >{
    ZPZoteroItem* _currentItem;
    iCarousel* _carousel;
    UIActivityIndicatorView* _activityIndicator;
    NSInteger _detailTitleWidth;
        
    NSCache* _previewCache;
}

- (void) configure;

@property (nonatomic, retain) ZPZoteroItem* selectedItem;

@end
