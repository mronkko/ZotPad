//
//  ZPAttacchmentThumbnailFactory.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 2/23/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ZPAttachmentThumbnailFactory.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>

@implementation ZPAttachmentThumbnailFactory


static ZPAttachmentThumbnailFactory* _instance;
static NSCache* _fileTypeImageCache;

+(ZPAttachmentThumbnailFactory*) instance{
    if(_instance == NULL){
        _instance = [[ZPAttachmentThumbnailFactory alloc] init];
        _fileTypeImageCache = [[NSCache alloc] init];
    }
    return _instance;
}

-(UIImage*) getFiletypeImage:(ZPZoteroAttachment*)attachment height:(NSInteger)height width:(NSInteger)width{
    
    NSString* key = [NSString stringWithFormat:@"%@%ix%i",attachment.attachmentType,height,width];
    
    UIImage* image = [_fileTypeImageCache objectForKey:key];
    
    if(image==NULL){
        NSLog(@"Getting file type image for %@ (%ix%i)",attachment.attachmentType,height,width);
        
        // Source: http://stackoverflow.com/questions/5876895/using-built-in-icons-for-mime-type-or-uti-type-in-ios
        
        //Need to initialize this way or the doc controller doesn't work
        NSURL*fooUrl = [NSURL URLWithString:@"file://foot.dat"];
        UIDocumentInteractionController* docController = [UIDocumentInteractionController interactionControllerWithURL:fooUrl];
        
        //Need to convert from mime type to a UTI to be able to get icons for the document
        CFStringRef mime = (__bridge CFStringRef) attachment.attachmentType;
        NSString *uti = (__bridge NSString*) UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType,mime, NULL);
        
        //Tell the doc controller what UTI type we want
        docController.UTI = uti;
        
        //Get the largest image that can fit
        
        for(UIImage* icon in docController.icons) {
            
            if(icon.size.width<width && icon.size.height<height) image=icon;
            else{
                if(image==NULL) image=icon;
                break;   
            }
        }
        
        NSLog(@"Using image with size ( %f x %f )",image.size.width,image.size.height);
        
        [_fileTypeImageCache setObject:image forKey:key];
    }
    
    return image;

}

@end
