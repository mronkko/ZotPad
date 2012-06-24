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
    BOOL _fileHasDefaultApp;
    UIActionSheet* _actionSheet;
    UIBarButtonItem* _sourceButton;
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
    
    else{
        NSURL* url= [NSURL fileURLWithPath:_activeAttachment.fileSystemPath];
        
        UIDocumentInteractionController* docController = [UIDocumentInteractionController interactionControllerWithURL:url];
        
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
        
        [_actionSheet addButtonWithTitle:@"Email"];
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

    }
    else{
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) buttonIndex++;
        else if(buttonIndex==1){
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
                UIDocumentInteractionController* docController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL URLWithString:_activeAttachment.fileSystemPath]];
                [docController presentOpenInMenuFromBarButtonItem:_ animated:<#(BOOL)#>
            }
            else if(buttonIndex==4){
                //Email
            }
            else if(buttonIndex==5){
                //Copy
                // Not implemented        

            }
            else if(buttonIndex==6){
                //Print
                // Not implemented        

            }
        }
    }

    _actionSheet = NULL;
}



@end
