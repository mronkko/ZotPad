//
//  ZPPreviewController.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 23.6.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"
#import "ZPDatabase.h"
#import "ZPPreviewController.h"
#import "ZPAttachmentFileInteractionController.h"
#import "ZPAttachmentCarouselDelegate.h"
#import "ZPPreviewSource.h"

//Unzipping and base64 decoding
#import "ZipArchive.h"
#import "NSString+Base64.h"

@interface ZPPreviewControllerDelegate : NSObject <QLPreviewControllerDataSource, QLPreviewControllerDelegate>{
    NSMutableArray* _previewItems;
}

- (void) addAttachmentToQuicklook:(ZPZoteroAttachment *)attachment;
- (NSInteger) startIndex;

@end

@implementation ZPPreviewControllerDelegate

-(id) init{
    self = [super init];
    _previewItems = [[NSMutableArray alloc] init];
    return self;
    
}

- (void) addAttachmentToQuicklook:(ZPZoteroAttachment *)attachment{
    
    //Do not add the object if it already exists
    if([_previewItems lastObject] == attachment) return;
    
    // Imported URLs need to be unzipped
    if([attachment.linkMode intValue] == LINK_MODE_IMPORTED_URL && ([attachment.contentType isEqualToString:@"text/html"] ||
                                                                    [attachment.contentType isEqualToString:@"application/xhtml+xml"])){
        
        //TODO: Make sure that this tempdir is cleaned at some point (Maybe refactor this into ZPZoteroAttachment)
        
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
            // The filenames end with %ZB64, which needs to be removed
            NSString* toBeDecoded = [file substringToIndex:[file length] - 5];
            NSString* decodedFilename = [toBeDecoded base64DecodedString];
            
            [[NSFileManager defaultManager] moveItemAtPath:[tempDir stringByAppendingPathComponent:file] toPath:[tempDir stringByAppendingPathComponent:decodedFilename] error:NULL];
            
        }
    }
    [_previewItems addObject:attachment];
}
 
// Item history is disabled because it was problematic to implement.
 
 - (NSInteger) startIndex{
     return 0;
// return [_previewItems count]-1;
 }

#pragma mark - Quick Look data source methods

- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller 
{
    return 1;
    //    return [_previewItems count];
}


- (id <QLPreviewItem>) previewController: (QLPreviewController *) controller previewItemAtIndex: (NSInteger) index{
    return [_previewItems lastObject];
    //return [_previewItems objectAtIndex:index];
}


// Should URL be opened
- (BOOL)previewController:(QLPreviewController *)controller shouldOpenURL:(NSURL *)url forPreviewItem:(id <QLPreviewItem>)item{
    return YES;
}

@end


@implementation ZPPreviewController

static ZPPreviewControllerDelegate* _sharedDelegate;

+(void) initialize{
    _sharedDelegate = [[ZPPreviewControllerDelegate alloc] init];
}

-(id) init{
    self=[super init];
    return self;
}

-(id) initWithAttachment:(ZPZoteroAttachment*)attachment source:(id <ZPPreviewSource>)source{
    
    self = [super init];
    
    _source = source;
    [_sharedDelegate addAttachmentToQuicklook:attachment];

    self.delegate = self;
    self.dataSource = _sharedDelegate;
    [self setCurrentPreviewItemIndex:[_sharedDelegate startIndex]];

    // Mark this file as recently viewed. This will be done also in the case
    // that the file cannot be downloaded because the fact that user tapped an
    // item is still relevant information for the cache controller
    
    
    [[ZPDatabase instance] updateViewedTimestamp:attachment];
    
    
    return self;
}


+(void) displayQuicklookWithAttachment:(ZPZoteroAttachment*)attachment source:(id <ZPPreviewSource>)source{
    
    if([attachment.linkMode intValue] == LINK_MODE_LINKED_URL){
        NSString* urlString = [[(ZPZoteroItem*)[ZPZoteroItem dataObjectWithKey:attachment.parentItemKey] fields] objectForKey:@"url"];
        
        //Links will be opened with safari.
        NSURL* url = [NSURL URLWithString: urlString];
        [[UIApplication sharedApplication] openURL:url];
    }
    
    //This should never be shown, but it is implemented just to be sure 
    
    else if(! attachment.fileExists){
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"File not found"
                                                          message:[NSString stringWithFormat:@"The file %@ was not found on ZotPad.",attachment.filename]
                                                         delegate:nil
                                                cancelButtonTitle:@"Cancel"
                                                otherButtonTitles:nil];
        
        [message show];
    }
    else {
        
        ZPPreviewController* quicklook = [[ZPPreviewController alloc] initWithAttachment:attachment source:(id <ZPPreviewSource>)source];
        
        UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;

        //Find the top most view controller.
        
        while(root.presentedViewController){
            root = root.presentedViewController;
        }
// For troubleshooting        
//        QLPreviewController* realQuickLook = [[QLPreviewController alloc] init];
//        realQuickLook.dataSource = quicklook.dataSource;
        [root presentModalViewController:quicklook animated:YES];
        
    }
    
}

-(void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    UIBarButtonItem* actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionButtonPressed:)];
    
    [[self navigationItem] setRightBarButtonItem:actionButton];

    //This is needed because the back and forward buttons do not render correctly
    
    if([self.navigationItem.leftBarButtonItems count] == 2){
        self.navigationItem.leftBarButtonItems = [NSArray arrayWithObject:[self.navigationItem.leftBarButtonItems objectAtIndex:0]];
        //TODO: Figure out what graphics the built in buttons use and configure the view properly
        //UIBarButtonItem* button = [self.navigationItem.leftBarButtonItems objectAtIndex:1];
        //UISegmentedControl* control = (UISegmentedControl*) button.customView;
        
    }
}

- (IBAction) actionButtonPressed:(id)sender{
    
    ZPZoteroAttachment* currentAttachment = (ZPZoteroAttachment*) self.currentPreviewItem;
    if(_attachmentInteractionController == NULL)  _attachmentInteractionController = [[ZPAttachmentFileInteractionController alloc] init];
    [_attachmentInteractionController setAttachment:currentAttachment];
    
    [_attachmentInteractionController presentOptionsMenuFromBarButtonItem:sender];
}

#pragma mark - Quick Look delegate methods

//Needed to provide zoom effect

- (CGRect)previewController:(QLPreviewController *)controller frameForPreviewItem:(id <QLPreviewItem>)item inSourceView:(UIView **)view{
    UIView* sourceView = [(id <ZPPreviewSource>) _source sourceViewForQuickLook]; 
    *view = sourceView;
    CGRect frame = sourceView.frame;
    return frame;
} 


- (UIImage *)previewController:(QLPreviewController *)controller transitionImageForPreviewItem:(id <QLPreviewItem>)item contentRect:(CGRect *)contentRect{
    UIView* sourceView = [(id <ZPPreviewSource>) _source sourceViewForQuickLook]; 

    if([sourceView isKindOfClass:[UIImageView class]]) return [(UIImageView*) sourceView image];
    else{
        UIGraphicsBeginImageContextWithOptions(sourceView.bounds.size, NO, 0);
        [sourceView.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        // Return the result
        return image;
    }
}




@end

