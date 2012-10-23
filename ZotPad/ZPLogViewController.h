//
//  ZPLogViewController.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 30.6.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

@interface ZPLogViewController : UIViewController  <MFMailComposeViewControllerDelegate, QLPreviewControllerDataSource>

@property (retain) IBOutlet UITextView* logView;
@property (retain) IBOutlet UIBarButtonItem* manualButton;

-(IBAction)showManual:(id)sender;
-(IBAction)contactSupport:(id)sender;
-(IBAction)manageKey:(id)sender;

-(IBAction)dismiss:(id)sender;

@end
