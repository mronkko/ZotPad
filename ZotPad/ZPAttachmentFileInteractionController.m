//
//  ZPThumbnailButtonTarget.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 1/2/12.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

// TODO: Rename this class so that it better reflects what it does (i.e. show the menu from the action button)

#import "ZPCore.h"

#import "ZPAttachmentFileInteractionController.h"



#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import "ZPItemDetailViewController.h"
#import "ZPItemLookup.h"


@interface ZPAttachmentFileInteractionController(){
    ZPZoteroAttachment* _activeAttachment;
    BOOL _fileCanBeOpened;
    UIActionSheet* _actionSheet;
    UIBarButtonItem* _sourceButton;
    UIDocumentInteractionController* _docController;
    UIPrintInteractionController* _printController;
    BOOL _docControllerActionSheetShowing;
    MFMailComposeViewController* _mailController;
    
    //Are we showing the main sheet or the lookup sheet
    BOOL _showsMainActionSheet;
}

- (BOOL) _shouldShowActionSheet;

@end



@implementation ZPAttachmentFileInteractionController

@synthesize item;

-(void) setAttachment:(ZPZoteroAttachment*)attachment{

    _activeAttachment = attachment;
    
    // Mark this file as recently viewed. This will be done also in the case
    // that the file cannot be downloaded because the fact that user tapped an
    // item is still relevant information for the cache controller
 
    [ZPDatabase updateViewedTimestamp:attachment];
}

- (BOOL) _shouldShowActionSheet{

    if(_actionSheet != NULL && _actionSheet.isVisible){
        [_actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
        return FALSE;
    }
    else if(_printController != NULL){
        [_printController dismissAnimated:YES];
        _printController = NULL;
        return FALSE;
    }
    else if(_docControllerActionSheetShowing){
        [_docController dismissMenuAnimated:YES];
        _docControllerActionSheetShowing = FALSE;
        return FALSE;
    }
    else return TRUE;

}


-(void) presentLookupMenuFromBarButtonItem:(UIBarButtonItem*)button{
    
    
    _sourceButton = button;
    _showsMainActionSheet = FALSE;

    if([self _shouldShowActionSheet]){
    
        NSString* cancel;
        
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) cancel = @"Cancel";
        
        _actionSheet = [[UIActionSheet alloc]
                        initWithTitle:nil
                        delegate:self
                        cancelButtonTitle:cancel
                        destructiveButtonTitle:nil
                        otherButtonTitles:nil];
        
        [_actionSheet addButtonWithTitle:@"Zotero Online Library"];
        [_actionSheet addButtonWithTitle:@"CrossRef Lookup"];
        [_actionSheet addButtonWithTitle:@"Google Scholar Search"];
        [_actionSheet addButtonWithTitle:@"Pubget Lookup"];
        [_actionSheet addButtonWithTitle:@"Library Lookup"];
        [_actionSheet showFromBarButtonItem:button animated:YES];

        _actionSheet.delegate = self;
    }
    
}

#pragma mark - Presenting the action menu

-(void) presentOptionsMenuFromBarButtonItem:(UIBarButtonItem*)button{
    
    _sourceButton = button;
    _showsMainActionSheet = TRUE;

    if([self _shouldShowActionSheet]){
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
        if([UIPrintInteractionController isPrintingAvailable] &&
           [UIPrintInteractionController canPrintURL:[NSURL fileURLWithPath:[_activeAttachment fileSystemPath]]])
                [_actionSheet addButtonWithTitle:@"Print"];
        
        // Options for the item
        [_actionSheet addButtonWithTitle:@"Lookup"];
        
        // Options for the attachment file

        [_actionSheet showFromBarButtonItem:button animated:YES];
        
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    //Add "empty indices" if the open buttons are not in use
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && buttonIndex > 0) buttonIndex++;
    
    if(_showsMainActionSheet){
        
        if( ! _fileCanBeOpened && buttonIndex > 1 ) buttonIndex++;
        if((![UIPrintInteractionController isPrintingAvailable] ||
            ! [UIPrintInteractionController canPrintURL:[NSURL fileURLWithPath:[_activeAttachment fileSystemPath]]]) && buttonIndex > 3)
        {
            buttonIndex++;
        }
        
        if(buttonIndex == 0){
            
            //Purge
            
            [_activeAttachment purge:@"Purged using action menu"];
            _actionSheet = NULL;
        }
        else if(buttonIndex==1){
            //Cancel
            _actionSheet = NULL;
        }
        else if(buttonIndex==2){
            //Open in...
            _docController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:_activeAttachment.fileSystemPath]];
            _docController.delegate = self;
            _docControllerActionSheetShowing = YES;
            [_docController presentOpenInMenuFromBarButtonItem:_sourceButton animated:YES];
            _actionSheet = NULL;
        }
        else if(buttonIndex==3){
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
            _actionSheet = NULL;
        }
        else if(buttonIndex==4){
            _printController = [UIPrintInteractionController sharedPrintController];
            _printController.delegate = self;
            [_printController setPrintingItem:[NSURL fileURLWithPath:[_activeAttachment fileSystemPath]]];
            
            if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
                [_printController presentAnimated:YES completionHandler:NULL];
            }
            else{
                [_printController presentFromBarButtonItem:_sourceButton animated:YES completionHandler:NULL];
            }
            _actionSheet = NULL;
        }
        else if(buttonIndex==5){
            // Look up
            _actionSheet = NULL;
            [self presentLookupMenuFromBarButtonItem:_sourceButton];
            
        }
    }
    
    //Lookup sheet
    else{
        if(buttonIndex==1){
            //Cancel
            _actionSheet = NULL;
        }

        /*
         
         [
         {
         "name": "CrossRef Lookup",
         "alias": "CrossRef",
         "icon": "file:///Users/mronkko/Documents/Zotero/locate/CrossRef%20Lookup.gif",
         "_urlTemplate": "http://crossref.org/openurl?{z:openURL}&pid=zter:zter321",
         "description": "CrossRef Search Engine",
         "hidden": false,
         "_urlParams": [],
         "_urlNamespaces": {
         "z": "http://www.zotero.org/namespaces/openSearch#",
         "": "http://a9.com/-/spec/opensearch/1.1/"
         },
         "_iconSourceURI": "http://crossref.org/favicon.ico"
         },
         {
         "name": "Google Scholar Search",
         "alias": "Google Scholar",
         "icon": "file:///Users/mronkko/Documents/Zotero/locate/Google%20Scholar%20Search.ico",
         "_urlTemplate": "http://scholar.google.com/scholar?as_q=&as_epq={z:title}&as_occt=title&as_sauthors={rft:aufirst?}+{rft:aulast?}&as_ylo={z:year?}&as_yhi={z:year?}&as_sdt=1.&as_sdtp=on&as_sdtf=&as_sdts=22&",
         "description": "Google Scholar Search",
         "hidden": false,
         "_urlParams": [],
         "_urlNamespaces": {
         "rft": "info:ofi/fmt:kev:mtx:journal",
         "z": "http://www.zotero.org/namespaces/openSearch#",
         "": "http://a9.com/-/spec/opensearch/1.1/"
         },
         "_iconSourceURI": "http://scholar.google.com/favicon.ico"
         },
         {
         "name": "Pubget Lookup",
         "alias": "Pubget",
         "icon": "file:///Users/mronkko/Documents/Zotero/locate/Pubget%20Lookup.ico",
         "_urlTemplate": "http://pubget.com/openurl?rft.title={rft:title}&rft.issue={rft:issue?}&rft.spage={rft:spage?}&rft.epage={rft:epage?}&rft.issn={rft:issn?}&rft.jtitle={rft:stitle?}&doi={z:DOI?}",
         "description": "Pubget Article Lookup",
         "hidden": false,
         "_urlParams": [],
         "_urlNamespaces": {
         "rft": "info:ofi/fmt:kev:mtx:journal",
         "z": "http://www.zotero.org/namespaces/openSearch#",
         "": "http://a9.com/-/spec/opensearch/1.1/"
         },
         "_iconSourceURI": "http://pubget.com/favicon.ico"
         }
         ]
         
         */
        
        _actionSheet = NULL;
    }
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

#pragma mark - UIPrintInteractionControllerDelegate

- (void)printInteractionControllerWillDismissPrinterOptions:(UIPrintInteractionController *)printInteractionController{
    _printController = NULL;
}


@end
