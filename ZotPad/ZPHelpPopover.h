//
//  ZPHelpPopover.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 7/15/12.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPHelpPopover : UIViewController <UIPopoverControllerDelegate>;

+ (void) displayHelpPopoverFromToolbarButton:(UIBarButtonItem*)button;

@end
