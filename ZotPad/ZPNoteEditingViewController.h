//
//  ZPNoteEditingViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 10/31/12.
//
//

#import "ZPCore.h"
#import <UIKit/UIKit.h>

@interface ZPNoteEditingViewController : UIViewController

@property (retain, nonatomic) ZPZoteroNote* note;
@property (retain, nonatomic) IBOutlet UIWebView* webView;

-(IBAction)cancel:(id)sender;
-(IBAction)save:(id)sender;

@end
