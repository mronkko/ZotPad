//
//  ZPFileImportView.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 8.4.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPCore.h"

#import "ZPFileImportViewController.h"
#include <QuartzCore/QuartzCore.h>
#import "ZPDataLayer.h"
#import "ZPServerConnection.h"
#import "ZPCacheController.h"

@interface ZPFileImportViewController ()

@end


@implementation ZPFileImportViewController

@synthesize url;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.

    //TODO: Refactor: move this into the storyboard

    self.view.layer.borderWidth = 2.0f;
    self.view.backgroundColor = [UIColor whiteColor];

    
    
}
- (void)viewWillAppear:(BOOL)animated{
    /*
    UIImage* fileImage = NULL;
    
    UIImageView* fileImageView = [[UIImageView alloc] initWithImage:fileImage];
    fileImageView.center = self.view.center;
    
    [self.view addSubview:fileImageView];
    

    TTStyledTextLabel* label = [[TTStyledTextLabel alloc] init];
    
    // Get the attachment object for this file. If not found, then print out an error
    // This method will always return an attachment object, so we need to check if the object has a parent set
    
    ZPZoteroAttachment* attachment = [ZPZoteroAttachment dataObjectForAttachedFile:[url absoluteString]];

    TTStyledText* text = NULL;
    
    if(attachment.title!=NULL){
        
        if([attachment fileExists]){
            _status = 0;
        }
        else{
            _status = 2;
        }
        
        ZPZoteroItem* parent = (ZPZoteroItem*)[ZPZoteroItem dataObjectWithKey:attachment.parentItemKey];
        
        text = [TTStyledText textFromXHTML:[NSString stringWithFormat:@"Updating attachment for item:\n\n %@ \n\n with received file: %@", [parent.fullCitation stringByReplacingOccurrencesOfString:@"&" 
                                                                                                                                                                                         withString:@"&amp;"],[[url pathComponents] lastObject]] lineBreaks:YES URLs:NO];
        
        label.frame=CGRectMake(0, 0, self.view.frame.size.width*.60, self.view.frame.size.height*.2);

    }
    else{
        _status = 1;
        //We could not identify the attachment, display alert
        text = [TTStyledText textFromXHTML:[NSString stringWithFormat:@"Received file %@", [[url pathComponents] lastObject]] lineBreaks:YES URLs:NO];
        label.frame=CGRectMake(0, 0, self.view.frame.size.width*.50, self.view.frame.size.height*.2);
    }
    
    [label setText:text];
     
    label.textColor = [UIColor whiteColor];
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = UITextAlignmentCenter;
    
    //Font size of TTStyledTextLabel cannot be set in interface builder, so must be done here
    [label setFont:[UIFont systemFontOfSize:[UIFont systemFontSize]]];
    
    label.center = self.view.center;
    
    UIView* background = [[UIView alloc] init];
    background.frame=CGRectMake(0, 0, self.view.frame.size.width*.7, self.view.frame.size.height*.3);
    background.backgroundColor=[UIColor blackColor];
    background.alpha = 0.5;
    background.layer.cornerRadius = 8;
    background.center = self.view.center;
    
    [self.view addSubview:background];
    [self.view addSubview:label];  
     */
}

- (void)viewDidAppear:(BOOL)animated{

    if(_status==0){
        ZPZoteroAttachment* attachment = [ZPZoteroAttachment dataObjectForAttachedFile:[self.url absoluteString]];
        //If we are online, check for conflicting files
        if([ZPServerConnection instance] != NULL){
           
            if([[ZPServerConnection instance] canUploadVersionForAttachment:attachment]){
                [[ZPCacheController instance] addAttachmentToUploadQueue:attachment withNewFile:self.url];
                [self dismissModalViewControllerAnimated:YES];
            }
            else{
                UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Version conflict"
                                                                message:@"Server refused the file upload. This is most likely because the file was modified on the server after it was downloaded. The file will be ignored."
                                                               delegate:self 
                                                      cancelButtonTitle:@"Cancel"
                                                      otherButtonTitles:nil];
                [alert show];

            }
            
        }
        else{
            //If we are not online, just add the item to queue and dismiss after a short delay
            [[ZPCacheController instance] addAttachmentToUploadQueue:attachment withNewFile:self.url];
            [self performSelector:@selector(dismissModalViewControllerAnimated:) withObject:[NSNumber numberWithBool:YES] afterDelay:3];
        }
        
    }
    else{
            
        if(_status==1){
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"File not identified"
                                                        message:@"ZotPad received a file that either does not have an identifier or the identifier does not match an existing file. The file will be ignored."
                                                       delegate:self 
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:nil];
            [alert show];
        
        }
        else if(_status==2){
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Original file not found"
                                                            message:@"ZotPad received a file that does not seem to match any file stored in the file cache. The file will be ignored."
                                                           delegate:self 
                                                  cancelButtonTitle:@"Cancel"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    }
    //Clean up inbox
    NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Inbox"];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:dbPath]){
        [[NSFileManager defaultManager] removeItemAtPath: dbPath error:NULL];   
    }

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

#pragma mark - Alert view delegate methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    [self dismissModalViewControllerAnimated:YES];
}
@end
