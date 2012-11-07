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

@property (retain, nonatomic) ZPZoteroDataObject<ZPZoteroDataObjectWithNote>* note;
@property (retain, nonatomic) IBOutlet UIWebView* webView;

+(ZPNoteEditingViewController*) instance;

-(IBAction)cancel:(id)sender;
-(IBAction)save:(id)sender;

@end
