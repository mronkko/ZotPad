//
//  ZPItemLookup.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 12/17/12.
//
//

#import "ZPCore.h"
#import <Foundation/Foundation.h>

@interface ZPItemLookup : NSObject <UIActionSheetDelegate>

@property (retain, nonatomic) ZPZoteroItem* item;

-(void) presentOptionsMenuFromBarButtonItem:(UIBarButtonItem*)button;

@end
