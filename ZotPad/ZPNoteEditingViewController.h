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

@interface ZPNoteEditingViewController : UIViewController <UIActionSheetDelegate>

@property (retain, nonatomic) IBOutlet UIWebView* webView;
@property (retain, nonatomic) IBOutlet UINavigationItem* navigationItem;

//@property (retain, nonatomic) NSObject<ZPNoteDisplay>* targetViewController;

+(ZPNoteEditingViewController*) instance;

-(void) configureWithNote:(ZPZoteroDataObject<ZPZoteroDataObjectWithNote>*) note andTarget:(UIViewController<ZPNoteDisplay>*) target isNew:(BOOL)isNew;

-(IBAction)cancel:(id)sender;
-(IBAction)save:(id)sender;
-(IBAction)deleteNote:(id)sender;

@end
