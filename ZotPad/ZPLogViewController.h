//
//  ZPLogViewController.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 30.6.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ZPLogViewController : UIViewController

@property (retain) IBOutlet UITextView* logView;

-(IBAction)showManual:(id)sender;
-(IBAction)onlineSupport:(id)sender;
-(IBAction)emailSupport:(id)sender;
-(IBAction)dismiss:(id)sender;

@end
