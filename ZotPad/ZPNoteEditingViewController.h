//
//  ZPNoteEditingViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 10/31/12.
//
//

#import "ZPCore.h"
#import "ZPNoteDisplay.h"
#import <UIKit/UIKit.h>

@interface ZPNoteEditingViewController : UIViewController

@property (retain, nonatomic) IBOutlet UIWebView* webView;
@property (retain, nonatomic) IBOutlet UINavigationItem* navigationItem;

@property (retain, nonatomic) ZPZoteroDataObject<ZPZoteroDataObjectWithNote>* note;
@property (retain, nonatomic) NSObject<ZPNoteDisplay>* targetViewController;

@property (assign) BOOL isNewNote;

+(ZPNoteEditingViewController*) instance;

-(IBAction)cancel:(id)sender;
-(IBAction)save:(id)sender;
-(IBAction)deleteNote:(id)sender;

@end
