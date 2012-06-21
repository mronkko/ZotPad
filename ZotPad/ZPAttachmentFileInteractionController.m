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

//Unzipping and base64 decoding
#import "ZipArchive.h"
#import "QSStrings.h"



@interface ZPAttachmentFileInteractionController(){
    ZPZoteroAttachment* _activeAttachment;
    BOOL _fileCanBeOpened;
    BOOL _fileHasDefaultApp;
}

- (void) _displayQuicklook;
- (void) _addAttachmentToQuicklook:(ZPZoteroAttachment *)attachment;

@end



@implementation ZPAttachmentFileInteractionController


static NSMutableArray* _fileURLs;

+(void) initialize{
    _fileURLs = [[NSMutableArray alloc] init];
}

-(id) initWithAttachment:(ZPZoteroAttachment*)attachment sourceView:(UIView*)view{

    self = [super init];

    _source = view;
    _activeAttachment = attachment;
    
    // Mark this file as recently viewed. This will be done also in the case
    // that the file cannot be downloaded because the fact that user tapped an
    // item is still relevant information for the cache controller
 
    
    [[ZPDatabase instance] updateViewedTimestamp:attachment];
            
    return self;
}


- (void) _addAttachmentToQuicklook:(ZPZoteroAttachment *)attachment{
    
    // Imported URLs need to be unzipped
    if([attachment.linkMode intValue] == LINK_MODE_IMPORTED_URL && [attachment.contentType isEqualToString:@"text/html"]){
        
        NSString* tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:attachment.key];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:tempDir]){
            [[NSFileManager defaultManager] removeItemAtPath:tempDir error:NULL];
        }
        [[NSFileManager defaultManager] createDirectoryAtPath:tempDir 
                                  withIntermediateDirectories:YES attributes:nil error:nil];
        ZipArchive* zipArchive = [[ZipArchive alloc] init];
        [zipArchive UnzipOpenFile:attachment.fileSystemPath];
        [zipArchive UnzipFileTo:tempDir overWrite:YES];
        [zipArchive UnzipCloseFile];

        //List the unzipped files and decode them
        
        NSArray* files = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:tempDir error:NULL];
        
        for (NSString* file in files){
            NSLog(@"Unzipped file %@ into temp dir %@",file,tempDir);
            // The filenames end with %ZB64, which needs to be removed
            NSString* toBeDecoded = [file substringToIndex:[file length] - 5];
            NSData* decodedData = [QSStrings decodeBase64WithString:toBeDecoded] ;
            NSString* decodedFilename = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
            NSLog(@"Decoded %@ as %@",toBeDecoded, decodedFilename);
        
            [[NSFileManager defaultManager] moveItemAtPath:[tempDir stringByAppendingPathComponent:file] toPath:[tempDir stringByAppendingPathComponent:decodedFilename] error:NULL];

        }
        
        [_fileURLs addObject:[NSURL fileURLWithPath:[tempDir stringByAppendingPathComponent:attachment.filename]]];
    }
    else{
        [_fileURLs addObject:[NSURL fileURLWithPath:attachment.fileSystemPath]];
    }
}


- (void) displayQuicklook{
    
    if([_activeAttachment.linkMode intValue] == LINK_MODE_LINKED_URL){
        NSString* urlString = [[(ZPZoteroItem*)[ZPZoteroItem dataObjectWithKey:_activeAttachment.parentItemKey] fields] objectForKey:@"url"];
        
        //Links will be opened with safari.
        NSURL* url = [NSURL URLWithString: urlString];
        [[UIApplication sharedApplication] openURL:url];
    }
    
    //This should never be shown, but it is implemented just to be sure 
    
    else if(! _activeAttachment.fileExists){
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"File not found"
                                                          message:[NSString stringWithFormat:@"The file %@ was not found on ZotPad.",_activeAttachment.filename]
                                                         delegate:nil
                                                cancelButtonTitle:@"Cancel"
                                                otherButtonTitles:nil];
        
        [message show];
    }
    else {
        [self _addAttachmentToQuicklook:_activeAttachment];

        QLPreviewController* quicklook = [[QLPreviewController alloc] init];
        [quicklook setDataSource:self];
        [quicklook setDelegate:self];

        [quicklook reloadData];
        [quicklook setCurrentPreviewItemIndex:[_fileURLs count]-1];
        
        UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;        
        [root presentModalViewController:quicklook animated:YES];

    }

}

#pragma mark - Presenting the action menu

-(void) presentOptionsMenuFromBarButtonItem:(UIBarButtonItem*)button{
    
    NSURL* url= [NSURL fileURLWithPath:_activeAttachment.fileSystemPath];
    
    UIDocumentInteractionController* docController = [UIDocumentInteractionController interactionControllerWithURL:url];
    
    _fileCanBeOpened = [docController presentOpenInMenuFromBarButtonItem:button animated: NO];
    [docController dismissMenuAnimated:NO];
    
    NSString* cancel;
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) cancel = @"Cancel";

    UIActionSheet *sheet = [[UIActionSheet alloc] 
                            initWithTitle:nil
                            delegate:self
                            cancelButtonTitle:cancel
                            destructiveButtonTitle:@"Purge"
                            otherButtonTitles:nil];
    if(_fileCanBeOpened){
        NSString* defaultApp = [[ZPPreferences instance] defaultApplicationForContentType:_activeAttachment.contentType];
        _fileHasDefaultApp = defaultApp!=NULL;
        if(_fileHasDefaultApp){
            [sheet addButtonWithTitle:[NSString stringWithFormat:@"Open in \"%@\"",defaultApp]];
        }
        [sheet addButtonWithTitle:@"Open in..."];
    }
    else{
        _fileHasDefaultApp = FALSE;
    }
    
    [sheet addButtonWithTitle:@"Email"];
    [sheet addButtonWithTitle:@"Copy"];
    [sheet addButtonWithTitle:@"Print"];
    
	[sheet showFromBarButtonItem:button animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    if(buttonIndex == 0){
        //Purge
        
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
            }
            else if(buttonIndex==3){
                //Open in...
            }
            else if(buttonIndex==4){
                //Email
            }
            else if(buttonIndex==5){
                //Copy
            }
            else if(buttonIndex==6){
                //Print
            }
        }
    }
}

#pragma mark - Quick Look data source methods

- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller 
{
    return [_fileURLs count];
}


- (id <QLPreviewItem>) previewController: (QLPreviewController *) controller previewItemAtIndex: (NSInteger) index{
    return [_fileURLs objectAtIndex:index];
}

#pragma mark - Quick Look delegate methods

//Needed to provide zoom effect

- (CGRect)previewController:(QLPreviewController *)controller frameForPreviewItem:(id <QLPreviewItem>)item inSourceView:(UIView **)view{
    *view = _source;
    CGRect frame = _source.frame;
    return frame; 
} 


- (UIImage *)previewController:(QLPreviewController *)controller transitionImageForPreviewItem:(id <QLPreviewItem>)item contentRect:(CGRect *)contentRect{
    if([_source isKindOfClass:[UIImageView class]]) return [(UIImageView*) _source image];
    else{
        UIImageView* imageView = (UIImageView*) [_source viewWithTag:1];
        return imageView.image;
    }
}

// Should URL be opened
- (BOOL)previewController:(QLPreviewController *)controller shouldOpenURL:(NSURL *)url forPreviewItem:(id <QLPreviewItem>)item{
    return YES;
}

@end
