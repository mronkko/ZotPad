//
//  ZPFileTransferProgressView.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/9/12.
//
//

#import "ZPFileTransferProgressView.h"
#import "ZPServerConnectionManager.h"

@implementation ZPFileTransferProgressView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

-(void) dealloc{
    [ZPServerConnectionManager removeProgressView:self];
}

@end
