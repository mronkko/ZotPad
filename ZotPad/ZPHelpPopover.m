//
//  ZPHelpPopover.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 7/15/12.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPHelpPopover.h"
#import <QuartzCore/QuartzCore.h>

@interface ZPHelpPopover(){
    id _target;
    SEL _action;
}

- (IBAction)dismiss:(id)sender;

@end

@implementation ZPHelpPopover

static UIPopoverController* helpPopover;

+ (void) displayHelpPopoverFromToolbarButton:(UIBarButtonItem*)button{
    
    ZPHelpPopover* content = [[ZPHelpPopover alloc] init];
    UILabel* label = [[UILabel alloc] init];
    label.text = @"Tap here for help";
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    [label sizeToFit];
    
    void (^animationLabel) (void) = ^{
        label.alpha = 0.5f;
    };
    void (^completionLabel) (BOOL) = ^(BOOL f) {
        label.alpha = 1;
    }; 
    
    NSUInteger opts =  UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat;
    [UIView animateWithDuration:0.5f delay:0 options:opts
                     animations:animationLabel completion:completionLabel];
    content.view=label;
    helpPopover = [[UIPopoverController alloc] initWithContentViewController:content];
    [helpPopover setPopoverContentSize:content.view.frame.size];
    [helpPopover presentPopoverFromBarButtonItem:button permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    
    helpPopover.delegate = content;
    
    //Configure the button to dismiss this
    content->_target = button.target;
    content->_action = button.action;
    button.target = content;
    button.action = @selector(dismiss:);
    
}

- (IBAction)dismiss:(id)sender{
    [helpPopover dismissPopoverAnimated:YES];
    [(UIBarButtonItem*)sender setTarget:_target];
    [(UIBarButtonItem*)sender setAction:_action];
    [_target performSelector:_action withObject:sender];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController{
    helpPopover = NULL;
}

@end
 
