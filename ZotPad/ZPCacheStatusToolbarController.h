//
//  ZPCacheStatusToolbarController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 2/22/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPCacheStatusToolbarController : NSObject{
    UIView* _view;
    UILabel* _fileUploads;
    UILabel* _fileDownloads;
    UILabel* _itemDownloads;
    UILabel* _cacheUsed;
}

@property (readonly) UIView* view;    

-(void) setFileDownloads:(NSInteger) value;
-(void) setFileUploads:(NSInteger) value;
-(void) setItemDownloads:(NSInteger) value;
-(void) setCacheUsed:(NSInteger) value;

@end
