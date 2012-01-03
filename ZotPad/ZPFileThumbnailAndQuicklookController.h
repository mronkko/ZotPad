//
//  ZPThumbnailButtonTarget.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 1/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroItem.h"
#import "ZPZoteroAttachment.h"

#import <Foundation/Foundation.h>

//For showing file thumbnails
#import <QuickLook/QuickLook.h>

@interface ZPFileThumbnailAndQuicklookController : NSObject <QLPreviewControllerDataSource>{
    ZPZoteroItem* _item;
    UIViewController* _viewController;
    NSInteger _maxWidth;
    NSInteger _maxHeight;
}

-(id) initWithItem:(ZPZoteroItem*)item viewController:(UIViewController*) viewController maxHeight:(NSInteger)maxHeight maxWidth:(NSInteger)maxWidth;
-(void) buttonTapped;
-(void) openInQuickLookWithAttachment:(ZPZoteroAttachment*) attachment;

-(UIButton*) thumbnailAsUIButton;
-(UIImageView*) thumbnailAsUIImageView:(NSInteger) index;

@end
