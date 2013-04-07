//
//  ZPCacheStatusToolbarController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 2/22/12.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPCacheStatusToolbarController : NSObject{
    UIView* _view;
    UILabel* _fileUploads;
    UILabel* _fileDownloads;
    UILabel* _itemDownloads;
    UILabel* _cacheUsed;
    UIView* _offlineModeOverlay;
}

@property (readonly) UIView* view;    

-(void) setFileDownloads:(NSInteger) value;
-(void) setFileUploads:(NSInteger) value;
-(void) setItemDownloads:(NSInteger) value;
-(void) setCacheUsed:(NSInteger) value;

//Display offline mode in the UI

-(void) notifyZotPadModeChanged:(NSNotification*) notification;

//Used by the offline switch

-(void) offlineSwitchChangedStatus:(UISwitch*) source;


@end
