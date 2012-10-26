//
//  ZPBarBackgroundGradientView.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 10/25/12.
//
//

#import "ZPBarBackgroundGradientView.h"
#import <QuartzCore/QuartzCore.h>

@implementation ZPBarBackgroundGradientView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

+(Class) layerClass {
    return [CAGradientLayer class];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
