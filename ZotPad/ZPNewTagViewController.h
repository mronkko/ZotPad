//
//  ZPNewTagViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/4/12.
//
//
#import "ZPCore.h"
#import <UIKit/UIKit.h>
#import "ZPTagEditingViewController.h"

@interface ZPNewTagViewController : UIViewController

@property (retain, nonatomic) IBOutlet UITextField* textField;
@property (retain, nonatomic) ZPTagEditingViewController* parent;

-(IBAction)createTag:(id)sender;

@end
