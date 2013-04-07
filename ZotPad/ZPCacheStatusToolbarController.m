//
//  ZPCacheStatusToolbarController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 2/22/12.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"
#import "ZPCacheStatusToolbarController.h"

#import "ZPItemDataDownloadManager.h"
#import "ZPItemDataUploadManager.h"
#import "ZPFileDownloadManager.h"
#import "ZPFileUploadManager.h"
#import "ZPFileCacheManager.h"

@interface ZPCacheStatusToolbarController()

-(void) _initOfflineOverlay;
-(void) _setOfflineOverlayVisible:(BOOL) visibility animated:(BOOL) animated;

@end

@implementation ZPCacheStatusToolbarController

@synthesize view = _view;

-(id) init{
    
    
    self=[super init];
    
    NSInteger titleWidth=95;
    NSInteger valueWidth=40;
    NSInteger height=11;
    
    NSArray* titles = [NSArray arrayWithObjects:@"File downloads:",@"File uploads:",@"Item downloads:",@"Cache space used:", nil];
    
    _view = [[UIView alloc] initWithFrame:CGRectMake(0,0, titleWidth*2+valueWidth*2, height*2)];
    
    NSInteger row=1;
    NSInteger col=1;
    for(NSString* title in titles){
        NSInteger baseX = (valueWidth+titleWidth)*(col-1);
        NSInteger baseY = (height)*(row-1);
        
        UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(baseX, baseY, titleWidth, height)];
        label.text = title;
        label.backgroundColor = [UIColor clearColor];
        label.font =  [UIFont fontWithName:@"Helvetica-Bold" size:10.0f];
        [_view addSubview:label];
        
        label = [[UILabel alloc] initWithFrame:CGRectMake(baseX+titleWidth, baseY, valueWidth, height)];
        label.text = @"0";
        label.backgroundColor = [UIColor clearColor];
        label.font =  [UIFont fontWithName:@"Helvetica-Bold" size:10.0f];
        [_view addSubview:label];
        
        if(row==1 && col==1){
            _fileDownloads = label;
        }
        else if(row==2 && col==1){
            _fileUploads = label;
        }
        else if(row==1 && col==2){
            _itemDownloads = label;
        }
        else if(row==2 && col==2){
            _cacheUsed = label;
        }
        
        row=row%2+1;
        if(row==1) col=col+1;
        
    }
    
    [ZPItemDataDownloadManager setStatusView:self];
    [ZPItemDataUploadManager setStatusView:self];
    [ZPFileDownloadManager setStatusView:self];
    [ZPFileUploadManager setStatusView:self];
    [ZPFileCacheManager setStatusView:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyZotPadModeChanged:)
                                                 name:ZPNOTIFICATION_ZOTPAD_MODE_CHANGED
                                               object:NULL];
    if(! [ZPPreferences online]){
        [self _setOfflineOverlayVisible:YES animated:NO];
    }
    
    return self;
    
}


-(void) setFileDownloads:(NSInteger) value{
    [_fileDownloads performSelectorOnMainThread:@selector(setText:) withObject:[NSString stringWithFormat:@"%i",value] waitUntilDone:NO];
}
-(void) setFileUploads:(NSInteger) value{
    [_fileUploads performSelectorOnMainThread:@selector(setText:) withObject:[NSString stringWithFormat:@"%i",value] waitUntilDone:NO];
}
-(void) setItemDownloads:(NSInteger) value{
    [_itemDownloads performSelectorOnMainThread:@selector(setText:) withObject:[NSString stringWithFormat:@"%i",value] waitUntilDone:NO];
}
-(void) setCacheUsed:(NSInteger) value{
    [_cacheUsed performSelectorOnMainThread:@selector(setText:) withObject:[NSString stringWithFormat:@"%i%%",value] waitUntilDone:NO];
}
-(void) notifyZotPadModeChanged:(NSNotification*) notification{
    if([NSThread isMainThread]){
        BOOL offline = ! [ZPPreferences online];
        if(! offline && _offlineModeOverlay != nil){
            [self _setOfflineOverlayVisible:NO animated:YES];
        }
        else if(offline && _offlineModeOverlay == nil){
            [self _setOfflineOverlayVisible:YES animated:YES];
        }
    }
    else{
        [self performSelectorOnMainThread:@selector(notifyZotPadModeChanged:) withObject:notification waitUntilDone:NO];
    }
}

-(void) _initOfflineOverlay{
    
    //Construct the offline overlay
    _offlineModeOverlay = [[UIView alloc] initWithFrame:_view.bounds];
    _offlineModeOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    UILabel* label = [[UILabel alloc] initWithFrame:_offlineModeOverlay.frame];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    label.text = @"Offline mode:";
    label.font = [UIFont boldSystemFontOfSize:17];
    label.backgroundColor = [UIColor clearColor];
    
    [_offlineModeOverlay addSubview:label];
    UISwitch* button = [UISwitch new];
    button.center = CGPointMake(_offlineModeOverlay.frame.size.width*3/4,
                                _offlineModeOverlay.frame.size.height/2);
    button.on = TRUE;
    [button addTarget:self
               action:@selector(offlineSwitchChangedStatus:)
     forControlEvents:UIControlEventValueChanged];
    
    [_offlineModeOverlay addSubview:button];
    
}

-(void) _setOfflineOverlayVisible:(BOOL) visibility animated:(BOOL) animated{
    
    if(visibility && _offlineModeOverlay == nil) [self _initOfflineOverlay];
    
    if(animated){
        if(visibility){
            _offlineModeOverlay.alpha = 0;
            [_view addSubview:_offlineModeOverlay];
        }
        
        _offlineModeOverlay.userInteractionEnabled = FALSE;
        
        [UIView animateWithDuration:0.5
                              delay:0
                            options: UIViewAnimationOptionCurveLinear
                         animations:^{
                             
                             _offlineModeOverlay.alpha = visibility;
                             
                             for(UIView* subview in _view.subviews){
                                 if (subview != _offlineModeOverlay) {
                                     subview.alpha = !visibility;
                                 }
                             }
                             
                         }
                         completion:^(BOOL finished){
                             
                             if(! visibility){
                                 [_offlineModeOverlay removeFromSuperview];
                                 _offlineModeOverlay = nil;
                             }
                             else{
                                 _offlineModeOverlay.userInteractionEnabled = TRUE;
                             }
                             
                         }];
        
    }
    else{
        for(UIView* subview in _view.subviews){
            if (subview != _offlineModeOverlay) {
                subview.alpha = !visibility;
            }
        }
        if(visibility){
            [_view addSubview:_offlineModeOverlay];
        }
        else{
            [_offlineModeOverlay removeFromSuperview];
            _offlineModeOverlay = nil;
        }
    }
}

-(void) offlineSwitchChangedStatus:(UISwitch*) source{
    BOOL offline = source.on;
    [ZPPreferences setOnline:! offline];
}

@end

