//
//  ZPStatusToolBar.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 2/22/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ZPStatusToolBar.h"

@implementation ZPStatusToolBar

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
}
*/

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSInteger titleWidth=50;
    NSInteger valueWidth=30;
    
    NSArray* titles = [NSArray arrayWithObjects:@"File downloads:",@"File uploads:",@"Item downloads:" nil];

    UIView* statusView = [[UIView alloc] initWithFrame:CGRectMake(0,0, titleWidth*2+valueWidth*2, )];

    NSInteger row=1;
    NSInteger col=1;
    for(NSString* title in titles){
        NSInteger baseX = (valueWidth+titleWidth)*col(; 
        UILabel* label = [UILabel alloc] initWithFrame:CGRectMake(, <#CGFloat y#>, <#CGFloat width#>, <#CGFloat height#>)
        label.text = title;
        label.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor whiteColor];
        label.font =  [UIFont fontWithName:@"Helvetica" size:8.0f];
                    
                    row=row%2+1;
                    if(row==1) col=col+1;

    }
    
    
    [button addTarget:self action:@selector(sortButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    button.tag = i;
    
    UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(sortButtonLongPressed:)];
    [button addGestureRecognizer:longPressRecognizer]; 
    
    UIBarButtonItem* barButton = [[UIBarButtonItem alloc] initWithCustomView:button];
    barButton.tag=i;
    
    [toobarItems addObject:barButton];
    [toobarItems addObject:spacer];

    //Add a label
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
