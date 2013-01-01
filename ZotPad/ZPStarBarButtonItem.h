//
//  ZPStarBarButtonItem.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 10/27/12.
//
//

#import <UIKit/UIKit.h>
#import "ZPCore.h"

@interface ZPStarBarButtonItem : UIBarButtonItem{
    ZPZoteroItem* _targetItem;
}

-(void) configureWithItem:(ZPZoteroItem*)item;

@end
