//
//  DemoViewController.m
//  DSActivityView Demo
//
//  Created by David Sinclair on 2009-07-30.
//  Copyright 2009-2011 Dejal Systems, LLC. All rights reserved.
//

#import "DemoViewController.h"
#import "DSActivityView.h"


@implementation DemoViewController

@synthesize useBezelStyle = _useBezelStyle, useKeyboardStyle = _useKeyboardStyle, showKeyboard = _showKeyboard, coverNavBar = _coverNavBar, useNetworkActivity = _useNetworkActivity, labelText1 = _labelText1, labelText2 = _labelText2, labelWidth = _labelWidth;

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    if (self.showKeyboard)
        [textField becomeFirstResponder];
    else
    {
        [textField resignFirstResponder];
        textField.hidden = YES;
    }
    
    if (self.useKeyboardStyle)
        showAgainButton.enabled = NO;
    else if (!self.useBezelStyle)
        showAgainButton.hidden = YES;
    
    [self performSelector:@selector(displayActivityView) withObject:nil afterDelay:0.8];
}

- (void)viewDidDisappear:(BOOL)animated;
{
	[super viewDidDisappear:animated];
    
    [self removeActivityView];
}

- (IBAction)displayActivityView;
{
    UIView *viewToUse = self.view;
    
    // Perhaps not the best way to find a suitable view to cover the navigation bar as well as the content?
    if (self.coverNavBar)
        viewToUse = self.navigationController.navigationBar.superview;
    
    if (self.useKeyboardStyle)
        showAgainButton.enabled = NO;
    else if (!self.useBezelStyle)
        showAgainButton.hidden = YES;
    
    if (self.labelText1)
    {
        // Display the appropriate activity style, with custom label text.  The width can be omitted or zero to use the text's width:
        if (self.useKeyboardStyle)
            [DSKeyboardActivityView newActivityViewWithLabel:self.labelText1];
        else if (self.useBezelStyle)
            [DSBezelActivityView newActivityViewForView:viewToUse withLabel:self.labelText1 width:self.labelWidth];
        else
            [DSActivityView newActivityViewForView:viewToUse withLabel:self.labelText1 width:self.labelWidth];
    }
    else
    {
        // Display the appropriate activity style, with the default "Loading..." text:
        if (self.useKeyboardStyle)
            [DSKeyboardActivityView newActivityView];
        else if (self.useBezelStyle)
            [DSBezelActivityView newActivityViewForView:viewToUse];
        else
            [DSActivityView newActivityViewForView:viewToUse];
    }
    
    // If this is YES, the network activity indicator in the status bar is shown, and automatically hidden when the activity view is removed.  This property can be toggled on and off as needed:
    if (self.useNetworkActivity)
        [DSActivityView currentActivityView].showNetworkActivityIndicator = YES;
    
    if (self.labelText2)
        [self performSelector:@selector(changeActivityView) withObject:nil afterDelay:3.0];
    else
        [self performSelector:@selector(removeActivityView) withObject:nil afterDelay:5.0];
}

- (void)changeActivityView;
{
    // Change the label text for the currently displayed activity view:
    [DSActivityView currentActivityView].activityLabel.text = self.labelText2;
    
    // Disable the network activity indicator in the status bar, e.g. after downloading data and starting parsing it (don't have to disable it if simply removing the view):
    if (self.useNetworkActivity)
        [DSActivityView currentActivityView].showNetworkActivityIndicator = NO;
    
    [self performSelector:@selector(removeActivityView) withObject:nil afterDelay:3.0];
}

- (void)removeActivityView;
{
    // Remove the activity view, with animation for the two styles that support it:
    if (self.useKeyboardStyle)
        [DSKeyboardActivityView removeViewAnimated:YES];
    else if (self.useBezelStyle)
        [DSBezelActivityView removeViewAnimated:YES];
    else
        [DSActivityView removeView];
    
    showAgainButton.enabled = YES;
    showAgainButton.hidden = NO;
    
    [[self class] cancelPreviousPerformRequestsWithTarget:self];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
{
    // All orientations are supported by the activity view:
    return YES;
}

- (void)didReceiveMemoryWarning;
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)dealloc;
{
    [_labelText1 release];
    [_labelText2 release];
    
    [super dealloc];
}


@end

