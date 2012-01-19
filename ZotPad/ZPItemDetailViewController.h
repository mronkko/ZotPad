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
#import "ZPSimpleItemListViewController.h"
#import "ZPFileThumbnailAndQuicklookController.h"


@interface ZPItemDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, iCarouselDataSource,
    iCarouselDelegate, ZPItemObserver, ZPAttachmentObserver, UISplitViewControllerDelegate>{
    ZPZoteroItem* _currentItem;
    UITableView* _detailTableView;
    iCarousel* _carousel;
    ZPSimpleItemListViewController* _itemListController;
    ZPFileThumbnailAndQuicklookController* _previewController;
    UIActivityIndicatorView* _activityIndicator;
    NSInteger _detailTitleWidth;
    NSArray* _carouselViews;
}

@property (nonatomic, retain) IBOutlet iCarousel* carousel;

@property (nonatomic, retain) ZPZoteroItem* selectedItem;

//This contains sections about the item details
@property (retain) IBOutlet UITableView* detailTableView;

-(void) configureWithItemKey:(NSString*)key;

@end
