//
//  ZPAttachmentPreviewViewController.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 17.4.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPCore.h"

#import "ZPAttachmentIconViewController.h"
#import "ZPZoteroAttachment.h"
#import "ZPPreferences.h"
#import <QuartzCore/QuartzCore.h>
#import "ZPDataLayer.h"
#import "ZPServerConnection.h"
#import <zlib.h>

#import "ZPLogger.h"

#define CHUNK 16384

@interface ZPAttachmentIconViewController (){
    UIGestureRecognizer* _tapRecognizer;
}

-(void) _configurePreview;
-(void) _configureTitleLabel;
-(void) _configureDownloadLabel;
-(void) _renderPDFPreview;
-(void) _showPDFPreview:(UIImage*) image;
-(void) _captureWebViewContent:(UIWebView*) webView forCacheKey:(NSString*) cacheKey;

@end

static NSCache* _previewCache; 
static NSCache* _fileIconCache; 
static NSMutableDictionary* _viewsWaitingForImage; 
static NSMutableDictionary* _viewsThatAreRendering; 
static ZPAttachmentIconViewController* _webViewDelegate;

@implementation ZPAttachmentIconViewController

@synthesize titleLabel;
@synthesize downloadLabel;
@synthesize cancelButton;
@synthesize progressView;
@synthesize fileImage;
@synthesize attachment;
@synthesize allowDownloading;
@synthesize usePreview;
@synthesize showLabel;
@synthesize labelBackground;
@synthesize errorLabel;


+ (void)initialize{

    _previewCache = [[NSCache alloc] init];
    [_previewCache setCountLimit:20];
    _fileIconCache = [[NSCache alloc] init];
    [_fileIconCache setCountLimit:20];
    _viewsWaitingForImage = [[NSMutableDictionary alloc] init ];
    _viewsThatAreRendering = [[NSMutableDictionary alloc] init ];
    _webViewDelegate = [[ZPAttachmentIconViewController alloc] init];
}

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
    NSLog(@"Loading view for ZPAttachmentPreviewViewController %x",self);

    [self _configurePreview];
    
    if(self.showLabel){
        // Do any additional setup after loading the view.
        
        if(self.allowDownloading){
            [self _configureDownloadLabel];
        }
        [self _configureTitleLabel];
        
        // Extra configuration not possible in Interface Builder
        self.labelBackground.layer.cornerRadius = 8;
        self.view.layer.borderWidth = 2.0f;
        
    }
    else{
        self.labelBackground.hidden = TRUE;
    }
}

- (void)viewDidUnload
{
    [[ZPDataLayer instance] removeAttachmentObserver:self];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


-(void) _configureDownloadLabel{
    
    
    self.downloadLabel.hidden = FALSE;

    if([[ZPServerConnection instance] isAttachmentDownloading:self.attachment]){
        [self notifyAttachmentDownloadStarted:attachment];
    }
    else{

        //Imported files and URLs have files that can be downloaded

        if(([attachment.linkMode intValue] == LINK_MODE_IMPORTED_FILE || [attachment.linkMode intValue] == LINK_MODE_IMPORTED_URL )
           && ! [attachment fileExists]){
            
            //Register self as observer for item downloads
            
            [[ZPDataLayer instance] registerAttachmentObserver:self];
            
            if([[ZPPreferences instance] online]){
                
                //TODO: Check if already downloading.
                
                NSString* source;
                if ([[ZPPreferences instance] useDropbox]) source = @"Dropbox";
                else if([[ZPPreferences instance] useWebDAV] && [attachment.libraryID intValue] == 1) source = @"WebDAV";
                else if ([attachment.existsOnZoteroServer intValue]==1) source = @"Zotero";
                
                if(source != NULL){
                    if(attachment.attachmentSize != [NSNull null]){
                        NSInteger size = [attachment.attachmentSize intValue];
                        self.downloadLabel.text =  [NSString stringWithFormat:@"Download from %@ (%i KB)",source,size/1024];
                    }
                    else{
                        self.downloadLabel.text = [NSString stringWithFormat:@"Download from %@ (unknown size)",source];
                    }
                }
                else {
                    self.downloadLabel.text = @"File cannot be found for download";
                }
            }
            else  self.downloadLabel.text = @"File cannot be downloaded when offline";
        }
        
        // Linked URL will be shown in directly from web 
        
        else if ([attachment.linkMode intValue] == LINK_MODE_LINKED_URL &&
                 !  [[ZPPreferences instance] online]){
            self.downloadLabel.text = @"Linked URL cannot be viewed in offline mode";
            
        }
        
        //Linked files are available only on the computer where they were created
        
        else if ([attachment.linkMode intValue] == LINK_MODE_LINKED_FILE) {
            self.downloadLabel.text = @"Linked files cannot be viewed from ZotPad";
        }
        
        else{
            self.downloadLabel.hidden = TRUE;
        }
    }    
}

-(void) _configureTitleLabel{
    
    //Add a label over the view
    NSString* extraInfo;
    
    //Imported files and URLs have files that can be downloaded
    
    if([attachment fileExists] && ![attachment.contentType isEqualToString:@"application/pdf"]){
        extraInfo = [@"Preview not supported for " stringByAppendingString:attachment.contentType];
    }
    else if ([attachment.linkMode intValue] == LINK_MODE_LINKED_URL &&
             [[ZPPreferences instance] online]){
        extraInfo = @"Preview not supported for linked URL";
        
    }
    
    //Add information over the thumbnail
    
    UILabel* label = self.titleLabel;
    
    if(extraInfo!=NULL) label.text = [NSString stringWithFormat:@"%@ \n\n(%@)", attachment.title, extraInfo];
    else label.text = [NSString stringWithFormat:@"%@", attachment.title];
    

}
-(void) _configurePreview{

    UIImage* image = NULL;
    
    if(attachment.fileExists && [attachment.contentType isEqualToString:@"application/pdf"]){
        
        image = [_previewCache objectForKey:attachment.fileSystemPath];
        
        if(image == NULL){
            [self performSelectorInBackground:@selector(_renderPDFPreview) withObject:NULL];
        }
    }
    
    if(image == NULL){
        [ZPAttachmentIconViewController renderFileTypeIconForAttachment:attachment intoImageView:self.fileImage];
    }
    else{
        [self _showPDFPreview:image];
    }
    
}


-(CGRect)_getDimensionsWithImage:(UIImage*) image{    
    
    float scalingFactor = self.view.frame.size.height/image.size.height;
    
    if(self.view.frame.size.height/image.size.width<scalingFactor) scalingFactor = self.view.frame.size.width/image.size.width;
    
    return CGRectMake(0,0,image.size.width*scalingFactor,image.size.height*scalingFactor);
    
}

+(void) renderFileTypeIconForAttachment:(ZPZoteroAttachment*) attachment intoImageView:(UIImageView*) fileImage {
    
    NSString* filename =[attachment.contentType stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    

    CGRect frame = fileImage.bounds;
    NSInteger width = (NSInteger)roundf(frame.size.width);
    NSInteger height = (NSInteger)roundf(frame.size.height);
    
    NSString* cacheKey = [filename stringByAppendingFormat:@"-%ix%i",width,height];

//    NSLog(@"Getting icon for %@",cacheKey);
    
    UIImage* cacheImage = NULL;
    BOOL render = false;
    @synchronized(_fileIconCache){
        cacheImage = [_fileIconCache objectForKey:cacheKey];
        if(cacheImage == NULL){
            [_fileIconCache setObject:[NSNull null] forKey:cacheKey];
            render = TRUE;
             
        }

    }

    //Check if we are currently rendering this and if we still need to keep rendering
    if(cacheImage == [NSNull null]){
        @synchronized(_viewsThatAreRendering){
            UIView* renderingView = [_viewsThatAreRendering objectForKey:cacheKey];
            //If the previous rendering view is no longer on screen
            if(renderingView != NULL && !(renderingView.superview)){
                NSLog(@"Previously rendering view %i is no longer on screen %@ (super: %i window %i)",renderingView, cacheKey, renderingView.superview, renderingView.window);

                render = TRUE;   
            }
        }
    }
    
    //No image in cache, and we are not currently rendering one either

    if(render){
        //If a file exists on disk, use that
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cachePath = [paths objectAtIndex:0];
        BOOL isDir = NO;
        NSError *error;
        if (! [[NSFileManager defaultManager] fileExistsAtPath:cachePath isDirectory:&isDir] && isDir == NO) {
            [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:NO attributes:nil error:&error];
        }
        
        if([[NSFileManager defaultManager] fileExistsAtPath:[cachePath stringByAppendingPathComponent:[cacheKey stringByAppendingString:@".png"]]]){
            NSLog(@"Loading image from disk %@",cacheKey);
            UIImage* image = [UIImage imageWithContentsOfFile:[cachePath stringByAppendingPathComponent:[cacheKey stringByAppendingString:@".png"]]];
            @synchronized(_fileIconCache){
                [_fileIconCache setObject:image forKey:cacheKey];
            }
            fileImage.image = image;
            
        }
        //Else start rendering
        else{
            if(![NSThread isMainThread]){
                [NSException raise:@"Rendering must be done in the main thread" format:@""];
            }
            UIWebView* webview = [[UIWebView alloc] initWithFrame:frame];
            
            NSLog(@"Start rendering cached image %@ with view %i",cacheKey,webview);
            
            NSString* filePath = [[[NSBundle mainBundle] resourcePath] 
                                  stringByAppendingPathComponent:[filename stringByAppendingString:@".svgz"]];
            
            if([[NSFileManager defaultManager] fileExistsAtPath:filePath]){
                
                //Uncompress the image
                
                NSString* pathString = NSTemporaryDirectory();
                NSLog(@"Render path is %@",pathString);
                NSString* tempFile = [pathString stringByAppendingPathComponent:[filename stringByAppendingString:@".svg"]];
                
                
                gzFile file = gzopen([filePath UTF8String], "rb");
                
                FILE *dest = fopen([tempFile UTF8String], "w");
                
                unsigned char buffer[CHUNK];
                
                int uncompressedLength;
                
                while (uncompressedLength = gzread(file, buffer, CHUNK) ) {
                    // got data out of our file
                    if(fwrite(buffer, 1, uncompressedLength, dest) != uncompressedLength || ferror(dest)) {
                        NSLog(@"error writing data");
                    }
                }
                
                fclose(dest);
                gzclose(file);  
                
                //Render the uncompressed file using a HTML file as a wrapper
                
                NSString* content = [NSString stringWithFormat:@"<html><body onload=\"document.location='zotpad:%@'\"><img src=\"%@.svg\" width=%i height=%i></body></html>",cacheKey,filename,width,height];          
                NSURL *baseURL = [NSURL fileURLWithPath:pathString];
                
                webview.delegate=_webViewDelegate;
                
                [webview loadData:[content dataUsingEncoding:NSUTF8StringEncoding] MIMEType:@"text/html" textEncodingName:NULL baseURL:baseURL];
                
                [fileImage addSubview:webview];
                
                @synchronized(_viewsThatAreRendering){
                    [_viewsThatAreRendering setObject:webview forKey:cacheKey];
                }
            }
        }
    }
    //IF the cache image is NSNull, this tells us that we are rendering an image currently
    else if(cacheImage == [NSNull null]){
        
        NSLog(@"Waiting for cached image %@",cacheKey);
        
        @synchronized(_viewsWaitingForImage){
            NSMutableArray* array= [_viewsWaitingForImage objectForKey:cacheKey];
            if(array == NULL){
                array = [[NSMutableArray alloc] init ];
                [_viewsWaitingForImage setObject:array forKey:cacheKey];
            }
            [array addObject:fileImage];
        }
    }
    //We have a cached image
    else{
//        NSLog(@"Using cached image %@",cacheKey);
        
        fileImage.image = cacheImage;
    }
}


- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
	NSString *requestString = [[request URL] absoluteString];
    NSArray* components = [requestString componentsSeparatedByString:@":"];
	if ([[components objectAtIndex:0] isEqualToString:@"zotpad"]) {
        [self _captureWebViewContent:webView forCacheKey:[components objectAtIndex:1]];
        
        @synchronized(_viewsThatAreRendering){
            [_viewsThatAreRendering removeObjectForKey:[components objectAtIndex:1]];
        }

		return NO;
	}
    
	return YES;
}

-(void) _captureWebViewContent:(UIWebView *)webview forCacheKey:(NSString*) cacheKey;{

    
    //If the view is still visible, capture the content
    if (webview.window && webview.superview) {
        
        NSLog(@"Capturing cached image %@ from view %i",cacheKey,webview);
        
        CGSize size = webview.bounds.size;
        
        if ([UIScreen instancesRespondToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0f) {
            UIGraphicsBeginImageContextWithOptions(size, NO, 2.0f);
        } else {
            UIGraphicsBeginImageContext(size);
        }
        
        [webview.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        // Write image to PNG
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cachePath = [paths objectAtIndex:0];
        BOOL isDir = NO;
        NSError *error;
        if (! [[NSFileManager defaultManager] fileExistsAtPath:cachePath isDirectory:&isDir] && isDir == NO) {
            [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:NO attributes:nil error:&error];
        }
        
        
        NSData* imageData = UIImagePNGRepresentation(image);
        
        //Create a blank image and compare to check that the image that we got is not blank.
        
        if ([UIScreen instancesRespondToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0f) {
            UIGraphicsBeginImageContextWithOptions(size, NO, 2.0f);
        } else {
            UIGraphicsBeginImageContext(size);
        }
        
        UIWebView* blankView = [[UIWebView alloc] initWithFrame:webview.frame];
        [blankView loadHTMLString:@"<html></html>" baseURL:NULL];
        [blankView.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *blankImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        if([UIImagePNGRepresentation(blankImage) isEqualToData:imageData]){
            @synchronized(_fileIconCache){
                
                NSLog(@"View %i produced a blank image. Clearing cahce for image %@",webview, cacheKey);
                
                [_fileIconCache removeObjectForKey:cacheKey];
            }
            
        }
        else{
            [imageData writeToFile:[cachePath stringByAppendingPathComponent:[cacheKey stringByAppendingString:@".png"]] atomically:YES];
            
            [(UIImageView*) webview.superview setImage:image];
            [webview removeFromSuperview];
            
            
            @synchronized(_fileIconCache){
                [_fileIconCache setObject:image forKey:cacheKey];
            }
            @synchronized(_viewsWaitingForImage){
                NSMutableArray* array= [_viewsWaitingForImage objectForKey:cacheKey];
                if(array != NULL){
                    [_viewsWaitingForImage removeObjectForKey:cacheKey];
                    for(UIImageView* view in array){
                        NSLog(@"Redrawing with cached image %@",cacheKey);
                        
                        view.image = image;
                    }
                }
            }
        }
    }
    else{
        @synchronized(_fileIconCache){

            NSLog(@"View %i no longer visible. Clearing cahce for image %@",webview, cacheKey);

            [_fileIconCache removeObjectForKey:cacheKey];
        }
        
    }

}

-(void) _showPDFPreview:(UIImage*) image {
    CGRect frame = [self _getDimensionsWithImage:image];
    self.fileImage.layer.frame = frame;
    self.fileImage.center = self.view.center;
    self.fileImage.layer.borderWidth = 2.0f;
    self.fileImage.layer.borderColor = [UIColor blackColor].CGColor;
    [self.fileImage setBackgroundColor:[UIColor whiteColor]]; 

    self.fileImage.image=image;

    //Set the old bacground transparent
    self.view.layer.borderColor = [UIColor clearColor].CGColor;
    [self.view setBackgroundColor:[UIColor clearColor]]; 

}

-(void) _renderPDFPreview{
    
    //
    // Renders a first page of a PDF as an image
    //
    // Source: http://stackoverflow.com/questions/5658993/creating-pdf-thumbnail-in-iphone
    //
    NSString* filename = attachment.fileSystemPath;
    
    NSLog(@"Start rendering pdf %@",filename);
    
    NSURL *pdfUrl = [NSURL fileURLWithPath:filename];
    CGPDFDocumentRef document = CGPDFDocumentCreateWithURL((__bridge_retained CFURLRef)pdfUrl);
    
    
    CGPDFPageRef pageRef = CGPDFDocumentGetPage(document, 1);
    CGRect pageRect = CGPDFPageGetBoxRect(pageRef, kCGPDFCropBox);
    
    UIGraphicsBeginImageContext(pageRect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, CGRectGetMinX(pageRect),CGRectGetMaxY(pageRect));
    CGContextScaleCTM(context, 1, -1);  
    CGContextTranslateCTM(context, -(pageRect.origin.x), -(pageRect.origin.y));
    CGContextDrawPDFPage(context, pageRef);
    
    UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if(image != NULL){
        NSLog(@"Done rendering pdf %@",filename);
        [_previewCache setObject:image forKey:filename];
        [self performSelectorOnMainThread:@selector(_showPDFPreview:) withObject:image waitUntilDone:NO];
    } 
    else{
        NSLog(@"Rendering pdf failed %@. File is now deleted because it is most likely corrupted",filename);
        [[[UIAlertView alloc] initWithTitle:@"File error" message:[NSString stringWithFormat:@"A downloaded attachment file (%@) could not be opened because it seems to be corrupted. The file will be now deleted and needs to be downloaded again.",attachment.filename]
                                  delegate:NULL cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        [[NSFileManager defaultManager] removeItemAtPath:filename error:NULL];
    }
}
#pragma mark - Attachment download observer protocol methods

-(void) notifyAttachmentDownloadCompleted:(ZPZoteroAttachment*) attachment{
    
    if(attachment == self.attachment){
        if ([NSThread isMainThread]){
            NSLog(@"Success");
            self.downloadLabel.text = @"Tap to view";
            if([attachment.contentType isEqualToString:@"application/pdf"]) [self _renderPDFPreview];
            self.progressView.hidden = TRUE;
            self.errorLabel.hidden = TRUE;
            self.view.userInteractionEnabled = TRUE;
            
        }
        else [self performSelectorOnMainThread:@selector(notifyAttachmentDownloadCompleted:) withObject:attachment waitUntilDone:NO];
    }
}
-(void) notifyAttachmentDownloadFailed:(ZPZoteroAttachment *)attachment withError:(NSError *)error{
    
    if(attachment == self.attachment){
        if ([NSThread isMainThread]){
            NSLog(@"Finished downloading %@",attachment.filename);
            self.downloadLabel.text = [NSString stringWithFormat:@"Download failed. (%@: %i)",error.domain,error.code];
            self.progressView.hidden = TRUE;
            NSString* description = [error.userInfo objectForKey:@"error"];
            if(description!=NULL){
                self.errorLabel.text=description;
                self.errorLabel.hidden = FALSE;
            }
            else{
                self.errorLabel.hidden = TRUE;
            }
            self.view.userInteractionEnabled = TRUE;
            
        }
        else{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self notifyAttachmentDownloadFailed:attachment withError:error];
            });
        }
    }
}

-(void) notifyAttachmentDownloadStarted:(ZPZoteroAttachment*) attachment{
    if(attachment == self.attachment){
        if ([NSThread isMainThread]){
            [[ZPServerConnection instance] useProgressView:self.progressView forAttachment:self.attachment];
            self.downloadLabel.text = @"Downloading";
            self.progressView.hidden = FALSE;
            self.errorLabel.hidden = TRUE;
            self.progressView.progress = 0;
            self.view.userInteractionEnabled = FALSE;
        }
        else [self performSelectorOnMainThread:@selector(notifyAttachmentDownloadStarted:) withObject:attachment waitUntilDone:NO];
    }

}

-(void) notifyAttachmentDeleted:(ZPZoteroAttachment*) attachment fileAttributes:(NSDictionary*) fileAttributes{
    if(attachment == self.attachment){
        if ([NSThread isMainThread]){
            NSLog(@"Attachment deleted %@",attachment.filename);
            self.downloadLabel.text = @"Attachment file deleted";
            self.progressView.hidden = TRUE;
            self.errorLabel.hidden = TRUE;
            self.view.userInteractionEnabled = TRUE;
            
        }
        else{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self notifyAttachmentDeleted:attachment fileAttributes:fileAttributes];
            });
        }
    }
}
@end
