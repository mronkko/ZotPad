//
//  ZPItemDetailViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/4/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

//For showing file thumbnails
#import <QuickLook/QuickLook.h>

#import <UIKit/UIKit.h>
#import "ZPZoteroItem.h"
#import "ZPAttachmentObserver.h"
#import "iCarousel.h"
#import "Three20/Three20.h"
#import "ZPSimpleItemListViewController.h"

@interface ZPItemDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, iCarouselDataSource, iCarouselDelegate, ZPItemObserver, ZPAttachmentObserver, QLPreviewControllerDataSource>{
    ZPZoteroItem* _currentItem;
    UITableView* _detailTableView;
    iCarousel* _carousel;
    TTStyledTextLabel* _fullCitationLabel;
    ZPSimpleItemListViewController* _itemListController;
}

@property (nonatomic, retain) IBOutlet iCarousel* carousel;

@property (nonatomic, retain) ZPZoteroItem* selectedItem;

//This contains sections about the item details
@property (retain) IBOutlet UITableView* detailTableView;

-(void) configureWithItemKey:(NSString*)key;

@end
