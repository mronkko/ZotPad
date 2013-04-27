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

#import "ZPOpenURL.h"
#import "ZPItemDetailViewController.h"
#import "NSString+URLEncoding.h"

// Needed for purging files
#import "ZPFileCacheManager.h"

#import "ZPGoodReaderIntegration.h"

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

@synthesize itemKey;
@synthesize actionSheet = _actionSheet;

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
        
        ZPZoteroItem* item =[ZPZoteroItem itemWithKey:itemKey];

        //These are not valid for webpages, attachments or notes
        if(! [item.itemType isEqualToString:@"note"] &&
           ! [item.itemType isEqualToString:@"attachment"] &&
           ! [item.itemType isEqualToString:@"webpage"]){
            [_actionSheet addButtonWithTitle:@"CrossRef Lookup"];
            [_actionSheet addButtonWithTitle:@"Google Scholar Search"];
            [_actionSheet addButtonWithTitle:@"Pubget Lookup"];
            [_actionSheet addButtonWithTitle:@"Library Lookup"];
        }
        [_actionSheet showFromBarButtonItem:button animated:YES];

        _actionSheet.delegate = self;
    }
    
}

#pragma mark - Presenting the action menu

-(void) presentOptionsMenuFromBarButtonItem:(UIBarButtonItem*)button{
    
    _sourceButton = button;
    _showsMainActionSheet = TRUE;

    if([self _shouldShowActionSheet]){
        
        // HTML files cannot be sent to other apps because images would not be
        // transfered
        
        if([_activeAttachment.contentType isEqualToString:@"text/html"] ||
           [_activeAttachment.contentType isEqualToString:@"application/xhtml+xml"]){
            _fileCanBeOpened = FALSE;
        }
        else{
            NSURL* url= [NSURL fileURLWithPath:_activeAttachment.fileSystemPath];
            
            UIDocumentInteractionController* docController = [UIDocumentInteractionController interactionControllerWithURL:url];
            docController.delegate = self;
            
            _fileCanBeOpened = [docController presentOpenInMenuFromBarButtonItem:button animated: NO];
            [docController dismissMenuAnimated:NO];
            
            if(! _fileCanBeOpened){
                DDLogWarn(@"File in path %@ cannot be opened", _activeAttachment.fileSystemPath);
            }
        }
        
        NSString* cancel;
        
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) cancel = @"Cancel";
        
         _actionSheet = [[UIActionSheet alloc] 
                                 initWithTitle:nil
                                 delegate:self
                                 cancelButtonTitle:cancel
                                 destructiveButtonTitle:@"Purge"
                                 otherButtonTitles:nil];
        
        if(_fileCanBeOpened){
            if([ZPGoodReaderIntegration isGoodReaderAppInstalled]) [_actionSheet addButtonWithTitle:@"Send to GoodReader"];
            [_actionSheet addButtonWithTitle:@"Open in..."];
        }
        
        if([MFMailComposeViewController canSendMail]) [_actionSheet addButtonWithTitle:@"Email"];
        if([UIPrintInteractionController isPrintingAvailable] &&
           [UIPrintInteractionController canPrintURL:[NSURL fileURLWithPath:[_activeAttachment fileSystemPath]]])
                [_actionSheet addButtonWithTitle:@"Print"];
        
        // Options for the item
        if(self.itemKey != nil){
            [_actionSheet addButtonWithTitle:@"Lookup"];
        }
        // Options for the attachment file

        [_actionSheet showFromBarButtonItem:button animated:YES];
        
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    
    if(_showsMainActionSheet){

        //Add "empty indices" if some buttons are not in use
        
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && buttonIndex > 0) buttonIndex++;

        
        if( ! _fileCanBeOpened && buttonIndex > 1 ) buttonIndex++;
        if(buttonIndex > 1 && (! [ZPGoodReaderIntegration isGoodReaderAppInstalled] || ! _fileCanBeOpened)) buttonIndex++;

        
        if((![UIPrintInteractionController isPrintingAvailable] ||
            ! [UIPrintInteractionController canPrintURL:[NSURL fileURLWithPath:[_activeAttachment fileSystemPath]]]) && buttonIndex > 4)
        {
            buttonIndex++;
        }
        
        if(buttonIndex == 0){
            
            //Purge
            if(_activeAttachment.fileExists_modified) [ZPFileCacheManager deleteModifiedFileForAttachment:_activeAttachment reason:@"Purged using action menu"];
            if(_activeAttachment.fileExists_original) [ZPFileCacheManager deleteOriginalFileForAttachment:_activeAttachment reason:@"Purged using action menu"];

                _actionSheet = NULL;
        }
        else if(buttonIndex==1){
            //Cancel
            _actionSheet = NULL;
        }
        else if(buttonIndex==2){
            //Send to good reader
            [ZPGoodReaderIntegration sendAttachmentToGoodReader:_activeAttachment];
        }
        else if(buttonIndex==3){
            //Open in...
            _docController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:_activeAttachment.fileSystemPath]];
            _docController.delegate = self;
            _docControllerActionSheetShowing = YES;
            [_docController presentOpenInMenuFromBarButtonItem:_sourceButton animated:YES];
            _actionSheet = NULL;
        }
        else if(buttonIndex==4){
            ZPZoteroItem* parentItem = [ZPZoteroItem itemWithKey:_activeAttachment.parentKey];
            _mailController = [[MFMailComposeViewController alloc] init];
            [_mailController setSubject:parentItem.shortCitation];
            [_mailController setMessageBody:[NSString stringWithFormat:@"<body>Please find the following file attached:<br>%@<br><br><small>Shared using <a href=\"http://www.zotpad.com\">ZotPad</a>, an iPad/iPhone client for Zotero</small></body>",parentItem.fullCitation] isHTML:YES];
                        
            [_mailController addAttachmentData:[NSData dataWithContentsOfFile:_activeAttachment.fileSystemPath ] mimeType:_activeAttachment.contentType fileName:_activeAttachment.filenameBasedOnLinkMode];
            _mailController.mailComposeDelegate = self;
            
            UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;
            while (root.presentedViewController!=NULL) root= root.presentedViewController;
            [root presentModalViewController:_mailController animated:YES];
            _actionSheet = NULL;
        }
        else if(buttonIndex==5){
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
        else if(buttonIndex==6){
            // Look up
            _actionSheet = NULL;
            [self presentLookupMenuFromBarButtonItem:_sourceButton];
            
        }
    }
    
    //Lookup sheet
    else{
        //Add "empty indices" if some buttons are not in use
        
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) buttonIndex++;

        ZPZoteroItem* item =[ZPZoteroItem itemWithKey:itemKey];
        
        if(buttonIndex==1){
            //Zotero online library
           [[UIApplication sharedApplication] openURL:[NSURL URLWithString:
                                                       [NSString stringWithFormat:@"https://www.zotero.org/%@/items/itemKey/%@",
                                                                                   (item.libraryID == LIBRARY_ID_MY_LIBRARY?
                                                                                    [ZPPreferences username]:
                                                                                    [NSString stringWithFormat:@"groups/%i",item.libraryID]),
                                                                                   item.key]]];
        }
        else if(buttonIndex==2){
            //CrossRef Lookup
            NSString* urlString = [NSString stringWithFormat:@"http://crossref.org/openurl?%@&pid=zter:zter321",[[[ZPOpenURL alloc] initWithZoteroItem:item] URLString]];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString: urlString]];
        }
        else if(buttonIndex==3){
            //Google Scholar search
            NSString* title = [item.title encodedURLString];
            NSMutableArray* authorsArray = [[NSMutableArray alloc] init];
            for(NSDictionary* author in item.creators){
                NSString* lastName = [author objectForKey:@"lastName"];
                if(lastName != NULL) [authorsArray addObject:lastName];
            }
            NSString* authors = [[authorsArray componentsJoinedByString:@" "] encodedURLString];
            NSString* year = item.year != 0 ? [NSString stringWithFormat:@"%i",item.year]: @"";
            
            NSString* urlString = [NSString stringWithFormat:@"http://scholar.google.com/scholar?as_q=&as_epq=%@&as_oq=&as_eq=&as_occt=title&as_sauthors=%@&as_publication=&as_ylo=%@&as_yhi=%@&btnG=&hl=en&as_sdt=0%%2C5",title, authors, year, year];
                                   
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:
                                                        urlString]];
        }
        else if(buttonIndex==4){
            //Pubget lookup
            ZPOpenURL* openURL = [[ZPOpenURL alloc] initWithZoteroItem:item];
            NSDictionary* fields = openURL.fields;

            NSString* jtitle = [[fields objectForKey:@"jtitle"] encodedURLString];
            if(jtitle == NULL) jtitle = @"";
            
            NSString* issue = [[fields objectForKey:@"issue"] encodedURLString];
            if(issue == NULL) issue = @"";
            
            NSString* spage = [[fields objectForKey:@"spage"] encodedURLString];
            if(spage == NULL) spage = @"";

            NSString* epage = [[fields objectForKey:@"epage"] encodedURLString];
            if(epage == NULL) epage = @"";

            NSString* issn = [[fields objectForKey:@"issn"] encodedURLString];
            if(issn == NULL) issn = @"";
            
            NSString* stitle = [[fields objectForKey:@"stitle"] encodedURLString];
            if(stitle == NULL) stitle = @"";

            NSString* doi = [[item.fields objectForKey:@"DOI"] encodedURLString];
            if(doi == NULL) doi = @"";

            
            NSString* urlString = [NSString stringWithFormat:@"http://pubget.com/openurl?rft.title=%@&rft.issue=%@&rft.spage=%@&rft.epage=%@&rft.issn=%@&rft.jtitle=%@&doi=%@",jtitle,issue,spage,epage,issn,stitle,doi];
           
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString: urlString]];

        }
        
        else if(buttonIndex == 5){
            //Library lookup
            NSString* urlString = [NSString stringWithFormat:@"http://worldcatlibraries.org/registry/gateway?%@",[[[ZPOpenURL alloc] initWithZoteroItem:item] URLString]];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString: urlString]];
        }
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
