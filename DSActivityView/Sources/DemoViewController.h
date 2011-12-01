//
//  DemoViewController.h
//  DSActivityView Demo
//
//  Created by David Sinclair on 2009-07-30.
//  Copyright 2009-2011 Dejal Systems, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface DemoViewController : UIViewController
{
    IBOutlet UITextField *textField;
    IBOutlet UIButton *showAgainButton;
    
    BOOL _useBezelStyle;
    BOOL _useKeyboardStyle;
    BOOL _showKeyboard;
    BOOL _coverNavBar;
    BOOL _useNetworkActivity;
    NSString *_labelText1;
    NSString *_labelText2;
    NSUInteger _labelWidth;
}

@property (nonatomic) BOOL useBezelStyle;
@property (nonatomic) BOOL useKeyboardStyle;
@property (nonatomic) BOOL showKeyboard;
@property (nonatomic) BOOL coverNavBar;
@property (nonatomic) BOOL useNetworkActivity;
@property (nonatomic, retain) NSString *labelText1;
@property (nonatomic, retain) NSString *labelText2;
@property (nonatomic) NSUInteger labelWidth;

- (IBAction)displayActivityView;
- (void)changeActivityView;
- (void)removeActivityView;

@end

