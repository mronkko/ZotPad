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

@interface ZPTagEditingViewController : UIViewController <ZPTagOwner>

@property (retain, nonatomic) ZPZoteroItem* item;
@property (retain, nonatomic) IBOutlet UITableView* tableView;
@property (retain, nonatomic) IBOutlet UINavigationBar* navigationBar;

-(IBAction)dismiss:(id)sender;
-(void)createTag:(NSString*)tag;

@end
