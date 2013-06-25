//
//  ZPModalViewController.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 6/21/13.
//
//

#import <UIKit/UIKit.h>

@interface ZPModalViewController : UIViewController

+(ZPModalViewController*) instance;
-(void) presentModally:(BOOL) animated;

@end
