//
//  ZPCacheStatusToolbarController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 2/22/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ZPCore.h"
#import "ZPCacheStatusToolbarController.h"
#import "ZPCacheController.h"

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
    [[ZPCacheController instance] setStatusView:self];
    
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

@end

