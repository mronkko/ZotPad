//
//  ZPThumbnailButtonTarget.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 1/2/12.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "ZPAttachmentFileInteractionController.h"



#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import "ZPItemDetailViewController.h"



@interface ZPAttachmentFileInteractionController(){
    ZPZoteroAttachment* _activeAttachment;
    BOOL _fileCanBeOpened;
    //This is not currently implemented
    BOOL _fileHasDefaultApp;
    UIActionSheet* _actionSheet;
    UIBarButtonItem* _sourceButton;
    UIDocumentInteractionController* _docController;
    BOOL _docControllerActionSheetShowing;
    MFMailComposeViewController* _mailController;
}

@end



@implementation ZPAttachmentFileInteractionController


-(void) setAttachment:(ZPZoteroAttachment*)attachment{

    _activeAttachment = attachment;
    
    // Mark this file as recently viewed. This will be done also in the case
    // that the file cannot be downloaded because the fact that user tapped an
    // item is still relevant information for the cache controller
 
    [ZPDatabase updateViewedTimestamp:attachment];
}



#pragma mark - Presenting the action menu

-(void) presentOptionsMenuFromBarButtonItem:(UIBarButtonItem*)button{
    
    _sourceButton = button;
    if(_actionSheet != NULL && _actionSheet.isVisible){
        [_actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
    }
    else if(_docControllerActionSheetShowing){
        [_docController dismissMenuAnimated:YES];
        _docControllerActionSheetShowing = FALSE;
    }
    else{
        NSURL* url= [NSURL fileURLWithPath:_activeAttachment.fileSystemPath];
        
        UIDocumentInteractionController* docController = [UIDocumentInteractionController interactionControllerWithURL:url];
        docController.delegate = self;
        
        _fileCanBeOpened = [docController presentOpenInMenuFromBarButtonItem:button animated: NO];
        [docController dismissMenuAnimated:NO];
        
        NSString* cancel;
        
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) cancel = @"Cancel";
        
         _actionSheet = [[UIActionSheet alloc] 
                                 initWithTitle:nil
                                 delegate:self
                                 cancelButtonTitle:cancel
                                 destructiveButtonTitle:@"Purge"
                                 otherButtonTitles:nil];
        
        if(_fileCanBeOpened){
            [_actionSheet addButtonWithTitle:@"Open in..."];
        }
        
        if([MFMailComposeViewController canSendMail]) [_actionSheet addButtonWithTitle:@"Email"];
// Not implemented        
//        [_actionSheet addButtonWithTitle:@"Copy"];
//        [_actionSheet addButtonWithTitle:@"Print"];
        
        [_actionSheet showFromBarButtonItem:button animated:YES];
        
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    if(buttonIndex == 0){

        //Purge

        [_activeAttachment purge:@"Purged using action menu"];
        
    }
    else{
        //iPad does not have cancel button
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) buttonIndex++;
    
        if(buttonIndex==1){
            //Cancel
        }
        else{
            //Add "empty indices" if the open buttons are not in use
            if( ! _fileCanBeOpened ) buttonIndex++;
            if( ! _fileHasDefaultApp ) buttonIndex++;
           
            if(buttonIndex==2){
                //Open with default app
                // Not implemented        
            }
            else if(buttonIndex==3){
                //Open in...
                _docController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:_activeAttachment.fileSystemPath]];
                _docController.delegate = self;
                _docControllerActionSheetShowing = YES;
                [_docController presentOpenInMenuFromBarButtonItem:_sourceButton animated:YES];
            }
            else if(buttonIndex==4){
                ZPZoteroItem* parentItem = [ZPZoteroItem itemWithKey:_activeAttachment.parentKey];
                _mailController = [[MFMailComposeViewController alloc] init];
                [_mailController setSubject:parentItem.shortCitation];
                [_mailController setMessageBody:[NSString stringWithFormat:@"<body>Please find the following file attached:<br>%@<br><br></body>",parentItem.fullCitation] isHTML:YES];
                
                //In the future, possibly include this small "advertisement"
                //<small>Shared using <a href=\"http://www.zotpad.com\">ZotPad</a>, an iPad/iPhone client for Zotero</small>
                
                [_mailController addAttachmentData:[NSData dataWithContentsOfFile:_activeAttachment.fileSystemPath ] mimeType:_activeAttachment.contentType fileName:_activeAttachment.filename];
                _mailController.mailComposeDelegate = self;
                
                UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;
                while (root.presentedViewController!=NULL) root= root.presentedViewController;
                [root presentModalViewController:_mailController animated:YES];                
            }
/*            else if(buttonIndex==5){
                //Copy
                // Not implemented        

            }
            else if(buttonIndex==6){
                //Print
                // Not implemented        

            }*/
        }
    }

    _actionSheet = NULL;
}

#pragma mark - UIDocumentInteractionControllerDelegate
- (void) documentInteractionController: (UIDocumentInteractionController *) controller didEndSendingToApplication: (NSString *) application{

    DDLogInfo(@"Sent file %@ and handed control to application %@", controller.name, application);
    
    //Store the version identifier. This is later used to upload modified files to Zotero
    
    if( _activeAttachment.versionIdentifier_local == NULL){
        if(_activeAttachment.versionIdentifier_server == NULL){
            DDLogCError(@"Server version identifier for attachment %@ was null",_activeAttachment.key);
            _activeAttachment.versionIdentifier_server = [ZPZoteroAttachment md5ForFileAtPath:_activeAttachment.fileSystemPath_original];
            //[NSException raise:@"Attachment version identifier cannot be null" format:@"Server version identifier for attachment %@ was null",_activeAttachment.key];
         }
         _activeAttachment.versionIdentifier_local = _activeAttachment.versionIdentifier_server;
    }
    
    [ZPDatabase writeVersionInfoForAttachment:_activeAttachment];
     
    _docControllerActionSheetShowing = FALSE;
}

- (void) documentInteractionControllerDidDismissOpenInMenu: (UIDocumentInteractionController *) controller{
    _docControllerActionSheetShowing = FALSE;
}

#pragma mark - MFMailComposeViewControllerDelegate

-(void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    [_mailController dismissModalViewControllerAnimated:YES];
    _mailController = NULL;
}

@end
