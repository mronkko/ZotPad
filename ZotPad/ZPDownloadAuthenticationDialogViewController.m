//
//  ZPDownloadAuthenticationDialogViewController.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 29.4.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPDownloadAuthenticationDialogViewController.h"

@interface ZPDownloadAuthenticationDialogViewController ()

@end

@implementation ZPDownloadAuthenticationDialogViewController

@synthesize passwordField;
@synthesize usernameField;
@synthesize caller;
@synthesize hostname;
@synthesize navigationItem;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    navigationItem.title=self.hostname;


}
- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}


-(IBAction)cancel:(id)sender{
    [caller setUsername:NULL andPassword:NULL];
    [self dismissModalViewControllerAnimated:YES];
}
-(IBAction)login:(id)sender{
    [caller setUsername:self.usernameField.text andPassword:self.passwordField.text];
    [self dismissModalViewControllerAnimated:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	
    CGRect f = CGRectInset([cell bounds], 10, 10);
	UITextField *textField = [[UITextField alloc] initWithFrame:f];
	[textField setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[textField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
	[textField setAutocorrectionType:UITextAutocorrectionTypeNo];
    [cell.contentView addSubview:textField];
    
	if (indexPath.row == 0) {
		[textField setPlaceholder:@"User"];
        [textField setSecureTextEntry:NO];
        [textField becomeFirstResponder];
        self.usernameField = textField;
	} else {
		[textField setPlaceholder:@"Password"];
		[textField setSecureTextEntry:YES];
        self.passwordField = textField;
    }    
	return cell;
}

- (NSString *)tableView:(UITableView *)aTableView titleForFooterInSection:(NSInteger)section
{
    return @"Password will be sent in the clear.";
    //			return @"Password will be sent securely.";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return 2;
}
@end
