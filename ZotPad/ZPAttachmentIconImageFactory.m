//
//  ZPAttachmentPreviewViewController.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 17.4.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPCore.h"

#import "ZPAttachmentIconImageFactory.h"
#import "ZPZoteroAttachment.h"
#import "ZPPreferences.h"
#import <QuartzCore/QuartzCore.h>
#import "ZPDataLayer.h"
#import "ZPServerConnection.h"
#import <zlib.h>



#define CHUNK 16384



@interface ZPAttachmentIconImageFactory ()

-(void) _captureWebViewContent:(UIWebView*) webView forCacheKey:(NSString*) cacheKey;
+(void) _uncompressSVGZ:(NSString*)name;
+(void) _showPDFPreview:(UIImage*) image inImageView:(UIImageView*) view;

@end

//TODO: This is commented out because there is currently no mechanism to expire items form the cache when files are changed on the disk
//static NSCache* _previewCache; 

static NSCache* _fileIconCache; 
static NSMutableDictionary* _viewsWaitingForImage; 
static NSMutableDictionary* _viewsThatAreRendering; 
static ZPAttachmentIconImageFactory* _webViewDelegate;

@implementation ZPAttachmentIconImageFactory


+ (void)initialize{
    
//    _previewCache = [[NSCache alloc] init];
//    [_previewCache setCountLimit:20];
    _fileIconCache = [[NSCache alloc] init];
    [_fileIconCache setCountLimit:20];
    _viewsWaitingForImage = [[NSMutableDictionary alloc] init ];
    _viewsThatAreRendering = [[NSMutableDictionary alloc] init ];
    _webViewDelegate = [[ZPAttachmentIconImageFactory alloc] init];
}


+(void) renderFileTypeIconForAttachment:(ZPZoteroAttachment*) attachment intoImageView:(UIImageView*) fileImage {
    
    NSString* mimeType =[attachment.contentType stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    
    CGRect frame = fileImage.bounds;
    NSInteger width = (NSInteger)roundf(frame.size.width);
    NSInteger height = (NSInteger)roundf(frame.size.height);
    
    NSString* emblem = @"";
    BOOL useEmblem=FALSE;
    if([attachment.linkMode intValue] == LINK_MODE_LINKED_URL){
        emblem =@"emblem-symbolic-link";
        useEmblem = TRUE;
    }else if( [attachment.linkMode intValue] == LINK_MODE_LINKED_FILE){
        emblem =@"emblem-locked";
        useEmblem = TRUE;
    }
    
    NSString* cacheKey = [mimeType stringByAppendingFormat:@"%@-%ix%i",emblem,width,height];
    
    //    DDLogVerbose(@"Getting icon for %@",cacheKey);
    
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
                DDLogVerbose(@"Previously rendering view %i is no longer on screen %@ (super: %i window %i)",renderingView, cacheKey, renderingView.superview, renderingView.window);
                
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
            DDLogVerbose(@"Loading image from disk %@",cacheKey);
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
            
            DDLogVerbose(@"Start rendering cached image %@ with view %i",cacheKey,webview);
            
                       if([[NSFileManager defaultManager] fileExistsAtPath:[[[NSBundle mainBundle] resourcePath] 
                                                                 stringByAppendingPathComponent:[mimeType stringByAppendingString:@".svgz"]]]){
                
                
                [self _uncompressSVGZ:mimeType];
                
                NSString* content;
                
                //Render the emblem
                if(useEmblem){
                    [self _uncompressSVGZ:emblem];
                    
                    //Render the uncompressed file using a HTML file as a wrapper
                    
                    content = [NSString stringWithFormat:@"<html><body onload=\"document.location='zotpad:%@'\"><div style=\"position: absolute; z-index:100\"><img src=\"%@.svg\" width=%i height=%i></div><img src=\"%@.svg\" width=%i height=%i></body></html>",cacheKey,emblem,width/4,height/4,mimeType,width,height];          
                }
                else{
                    content = [NSString stringWithFormat:@"<html><body onload=\"document.location='zotpad:%@'\"><img src=\"%@.svg\" width=%i height=%i></body></html>",cacheKey,mimeType,width,height];          
                }
                
                DDLogVerbose(content);
                
                NSURL *baseURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
                
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
        
        DDLogVerbose(@"Waiting for cached image %@",cacheKey);
        
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
        //        DDLogVerbose(@"Using cached image %@",cacheKey);
         DDLogVerbose(@"Using cached image %@ for view %@",cacheKey,fileImage);
        fileImage.image = cacheImage;
    }
}

+(void) _uncompressSVGZ:(NSString *)filePath{
    
    //Uncompress the image
    NSString* sourceFile = [[[NSBundle mainBundle] resourcePath] 
                            stringByAppendingPathComponent:[filePath stringByAppendingString:@".svgz"]];
    
    NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[filePath stringByAppendingString:@".svg"]];
    
    gzFile file = gzopen([sourceFile UTF8String], "rb");
    
    FILE *dest = fopen([tempFile UTF8String], "w");
    
    unsigned char buffer[CHUNK];
    
    int uncompressedLength;
    
    while (uncompressedLength = gzread(file, buffer, CHUNK) ) {
        // got data out of our file
        if(fwrite(buffer, 1, uncompressedLength, dest) != uncompressedLength || ferror(dest)) {
            DDLogVerbose(@"error writing data");
        }
    }
    
    fclose(dest);
    gzclose(file);  
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
        
        DDLogVerbose(@"Capturing cached image %@ from view %i",cacheKey,webview);
        
        CGSize size = webview.bounds.size;
        
        if ([UIScreen instancesRespondToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0f) {
            UIGraphicsBeginImageContextWithOptions(size, NO, 2.0f);
        } else {
            UIGraphicsBeginImageContextWithOptions(size, NO, 1.0f);
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
                
                DDLogVerbose(@"View %i produced a blank image. Clearing cahce for image %@",webview, cacheKey);
                
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
                        DDLogVerbose(@"Redrawing with cached image %@",cacheKey);
                        
                        view.image = image;
                    }
                }
            }
        }
    }
    else{
        @synchronized(_fileIconCache){
            
            DDLogVerbose(@"View %i no longer visible. Clearing cahce for image %@",webview, cacheKey);
            
            [_fileIconCache removeObjectForKey:cacheKey];
        }
        
    }
    
}

+(void) _showPDFPreview:(UIImage*) image inImageView:(UIImageView*) imageView{
    
    DDLogVerbose(@"Setting PDF preview to imageView %@",imageView);
    CGRect frame = [self getDimensionsForImageView:imageView.superview withImage:image];
    imageView.frame = frame;
    imageView.center = imageView.superview.center;
    imageView.layer.borderWidth = 2.0f;
    imageView.layer.borderColor = [UIColor blackColor].CGColor;
    [imageView setBackgroundColor:[UIColor whiteColor]]; 
    
    imageView.image=image;
    
    //Set the old bacground transparent
    imageView.superview.layer.borderColor = [UIColor clearColor].CGColor;
    imageView.superview.backgroundColor = [UIColor clearColor]; 
    
}

+(CGRect) getDimensionsForImageView:(UIImageView*) imageView withImage:(UIImage*) image{   
    
    float scalingFactor = MIN(imageView.frame.size.height/image.size.height,imageView.frame.size.width/image.size.width);
    
    float newWidth = image.size.width*scalingFactor;
    float newHeight = image.size.height*scalingFactor;

    DDLogVerbose(@"Dimensions (width x height) image: %f x %f view:  %f x %f, return %f x %f",image.size.width,image.size.height,imageView.frame.size.width,imageView.frame.size.height,newWidth,newHeight);

    return CGRectMake(0,0,newWidth,newHeight);
    
}

+(void) renderPDFPreviewForFileAtPath:(NSString*) filePath intoImageView:(UIImageView*) fileImage{
    
    if([NSThread isMainThread]){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{
            [ZPAttachmentIconImageFactory renderPDFPreviewForFileAtPath:filePath intoImageView:fileImage];
        });

    }
    else{
        //
        // Renders a first page of a PDF as an image
        //
        // Source: http://stackoverflow.com/questions/5658993/creating-pdf-thumbnail-in-iphone
        //
        
        
        DDLogVerbose(@"Start rendering pdf %@",filePath);
        
        NSURL *pdfUrl = [NSURL fileURLWithPath:filePath];
        CGPDFDocumentRef document = CGPDFDocumentCreateWithURL((__bridge_retained CFURLRef)pdfUrl);
        
        
        CGPDFPageRef pageRef = CGPDFDocumentGetPage(document, 1);
        CGRect pageRect = CGPDFPageGetBoxRect(pageRef, kCGPDFCropBox);
        
        UIGraphicsBeginImageContext(pageRect.size);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        //If something goes wrong, we might get an empty context
        if (context != NULL) {

            CGContextTranslateCTM(context, CGRectGetMinX(pageRect),CGRectGetMaxY(pageRect));
            CGContextScaleCTM(context, 1, -1);  
            CGContextTranslateCTM(context, -(pageRect.origin.x), -(pageRect.origin.y));
            CGContextDrawPDFPage(context, pageRef);
            
            UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            if(image != NULL){
                DDLogVerbose(@"Done rendering pdf %@",filePath);
                //        [_previewCache setObject:image forKey:filePath];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self _showPDFPreview:image inImageView:fileImage];
                });
            } 
        }
    }
}

@end
