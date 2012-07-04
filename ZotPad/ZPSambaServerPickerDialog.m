//
//  ZPSambaServerPickerDialog.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 29.4.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPSambaServerPickerDialog.h"
#import "ZPPreferences.h"

@interface ZPSambaServerPickerDialog (){
    NSArray* _servers;
}

@end

@implementation ZPSambaServerPickerDialog

@synthesize caller;

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
    
    UITableView* table = (UITableView*) [self.view viewWithTag:1];
    
    [table setDataSource:self];
    [table setDelegate:self];
    
    UILabel* label = (UILabel*) [self.view viewWithTag:2];
    NSString* shareName = [[ZPPreferences instance] sambaShareName];
    
    label.text = [NSString stringWithFormat:@"Choose a computer that you are currently using to share your Zotero files with SMB. ZotPad will attempt to connect to a share named '%@' on the chosen server. \n\nWarning: SMB is insecure and should be used only on trusted networks.",shareName];
    
    UIButton* button = (UIButton*)  [self.view viewWithTag:3];
    [button addTarget:self action:@selector(disableSamba:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton* cancelButton = (UIButton*)  [self.view viewWithTag:4];
    [cancelButton addTarget:self action:@selector(cancelButton:) forControlEvents:UIControlEventTouchUpInside];

    @synchronized(caller){
        _servers = [NSArray arrayWithArray:caller.knownServers];
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

-(void)viewDidDisappear:(BOOL)animated{
    [caller dialogDismissed];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Tableview delegate and data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return MAX([_servers count],1);
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if([_servers count]>0){
        caller.hostname = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;
        [self dismissModalViewControllerAnimated:YES];
    }
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    if(indexPath.row==0 && [_servers count] == 0){
        return [tableView dequeueReusableCellWithIdentifier:@"NoServersCell"];
    }
    else{
        
        UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"ServerNameCell"];
        NSString* serverName = [_servers objectAtIndex:indexPath.row];
        [cell.textLabel setText:serverName];
        return cell;
    }
}

#pragma mark - Button actions

-(IBAction)disableSamba:(id)sender{
    [self dismissModalViewControllerAnimated:YES];
    [caller disableSamba];
}

-(IBAction)cancelSamba:(id)sender{
    [self dismissModalViewControllerAnimated:YES];
    [caller cancelCurrent];
}

@end
