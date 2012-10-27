//
//  ZPItemDetailViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/4/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//


#import <UIKit/UIKit.h>


#import "iCarousel.h"
#import "ZPAttachmentFileInteractionController.h"



@interface ZPItemDetailViewController : UITableViewController <UINavigationControllerDelegate >{
    ZPZoteroItem* _currentItem;
    iCarousel* _carousel;
    UIActivityIndicatorView* _activityIndicator;
    NSInteger _detailTitleWidth;
        
    NSCache* _previewCache;
}

- (void) configure;
- (IBAction) actionButtonPressed:(id)sender;

@property (nonatomic, retain) IBOutlet UIBarButtonItem* actionButton;
@property (nonatomic, retain) ZPZoteroItem* selectedItem;

@end
