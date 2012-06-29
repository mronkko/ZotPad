//
//  ZPThumbnailButtonTarget.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 1/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ZPCore.h"

#import "ZPAttachmentFileInteractionController.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroAttachment.h"
#import "ZPDatabase.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import "ZPItemDetailViewController.h"
#import "ZPServerConnection.h"

#import "ZPPreferences.h"
#import "ZPDataLayer.h"
#import "ZPLogger.h"


//Presenting previews
#import "ZPPreviewController.h"

@interface ZPAttachmentFileInteractionController(){
    ZPZoteroAttachment* _activeAttachment;
    BOOL _fileCanBeOpened;
    //This is not currently implemented
    BOOL _fileHasDefaultApp;
    UIActionSheet* _actionSheet;
    UIBarButtonItem* _sourceButton;
    UIDocumentInteractionController* _docController;
    BOOL _docControllerActionSheetShowing;
}

@end



@implementation ZPAttachmentFileInteractionController


-(void) setAttachment:(ZPZoteroAttachment*)attachment{

    _activeAttachment = attachment;
    
    // Mark this file as recently viewed. This will be done also in the case
    // that the file cannot be downloaded because the fact that user tapped an
    // item is still relevant information for the cache controller
 
    [[ZPDatabase instance] updateViewedTimestamp:attachment];
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
            NSString* defaultApp = [[ZPPreferences instance] defaultApplicationForContentType:_activeAttachment.contentType];
            _fileHasDefaultApp = defaultApp!=NULL;
            if(_fileHasDefaultApp){
                [_actionSheet addButtonWithTitle:[NSString stringWithFormat:@"Open in \"%@\"",defaultApp]];
            }
            [_actionSheet addButtonWithTitle:@"Open in..."];
        }
        else{
            _fileHasDefaultApp = FALSE;
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

        //TODO: refactor file removals to a separate method
        
        NSString* path = _activeAttachment.fileSystemPath;
        NSDictionary *_documentFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES];
            
        [[NSFileManager defaultManager] removeItemAtPath:path error: NULL];
        [[ZPDataLayer instance] notifyAttachmentDeleted:_activeAttachment fileAttributes:_documentFileAttributes];
        
        //Dismiss the preview controller if it is visible
        UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;
        UIViewController* vc = [root modalViewController];
        if(vc!=NULL && [vc isKindOfClass:[ZPPreviewController class]]) [root dismissModalViewControllerAnimated:YES];

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
                ZPZoteroItem* parentItem = [ZPZoteroItem dataObjectWithKey:_activeAttachment.parentItemKey];
                MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
                [mailController setSubject:parentItem.shortCitation];
                [mailController setMessageBody:[NSString stringWithFormat:@"<body>Please find the following file attached:<br>%@<br><br></body>",parentItem.fullCitation] isHTML:YES];
                
                //In the future, possibly include this small "advertisement"
                //<small>Shared using <a href=\"http://www.zotpad.com\">ZotPad</a>, an iPad/iPhone client for Zotero</small>
                
                [mailController addAttachmentData:[NSData dataWithContentsOfFile:_activeAttachment.fileSystemPath ] mimeType:_activeAttachment.contentType fileName:_activeAttachment.filename];
                mailController.mailComposeDelegate = self;
                
                UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;      
                [root presentModalViewController:mailController animated:YES];                
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
    NSLog(@"Handed control to application %@",application);
    
    //Store the version identifier. This is later used to upload modified files to Zotero
    
    if(_activeAttachment.versionIdentifier_local == [NSNull null] || _activeAttachment.versionIdentifier_local == NULL){
        _activeAttachment.versionIdentifier_local = _activeAttachment.versionIdentifier_server;
    }
    
    [[ZPDatabase instance] writeVersionInfoForAttachment:_activeAttachment];
     
    _docControllerActionSheetShowing = FALSE;
}

- (void) documentInteractionControllerDidDismissOpenInMenu: (UIDocumentInteractionController *) controller{
    _docControllerActionSheetShowing = FALSE;
}

#pragma mark - MFMailComposeViewControllerDelegate

-(void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;      
    [root dismissModalViewControllerAnimated:YES];
}

@end
