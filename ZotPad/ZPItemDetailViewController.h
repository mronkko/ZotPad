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

@interface ZPItemDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, iCarouselDataSource,
    iCarouselDelegate, ZPItemObserver, ZPAttachmentObserver, UINavigationControllerDelegate >{
    ZPZoteroItem* _currentItem;
    UITableView* _detailTableView;
    iCarousel* _carousel;
    UIActivityIndicatorView* _activityIndicator;
    NSInteger _detailTitleWidth;
        
    NSCache* _previewCache;
}

- (void) configure;

@property (nonatomic, retain) IBOutlet iCarousel* carousel;
@property (nonatomic, retain) ZPZoteroItem* selectedItem;

//This contains sections about the item details
@property (retain) IBOutlet UITableView* detailTableView;

@end
