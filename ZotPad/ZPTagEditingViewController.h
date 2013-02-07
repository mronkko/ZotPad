//
//  ZPTagEditingViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/3/12.
//
//

#import <UIKit/UIKit.h>
#import "ZPCore.h"
#import "ZPTagOwner.h"
#import "ZPTagDisplay.h"

@interface ZPTagEditingViewController : UIViewController <ZPTagOwner>

@property (retain, nonatomic) IBOutlet UITableView* tableView;
@property (retain, nonatomic) IBOutlet UINavigationBar* navigationBar;

@property (retain, nonatomic) ZPZoteroDataObject* item;
@property (retain, nonatomic) NSObject<ZPTagDisplay>* targetViewController;

+(ZPTagEditingViewController*) instance;
-(IBAction)dismiss:(id)sender;
-(IBAction)showPopover:(id)sender;
-(void)createTag:(NSString*)tag;

@end
