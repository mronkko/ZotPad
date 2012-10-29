//
//  ZPStarBarButtonItem.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 10/27/12.
//
//

#import "ZPStarBarButtonItem.h"

@implementation ZPStarBarButtonItem

-(id) init{
    self = [super init];
    
    self.image = [UIImage imageNamed:@"InactiveStar"];
    self.style = UIBarButtonItemStylePlain;
    self.target = self;
    self.action = @selector(toggleStar:);
    
    return self;
}

- (void) toggleStar:(id)sender{
    if(self.image == [UIImage imageNamed:@"ActiveStar"]){
        self.image = [UIImage imageNamed:@"InactiveStar"];
    }
    else{
        self.image = [UIImage imageNamed:@"ActiveStar"];
    }
}

@end
