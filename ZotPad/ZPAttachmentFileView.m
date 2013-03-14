//
//  ZPAttachmentFileView.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 3/14/13.
//
//

#import "ZPAttachmentFileView.h"

@implementation ZPAttachmentFileView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}


-(void) setShouldObserveUploads:(BOOL) observeUploads{
    
/*
 
        [ZPFileUploadManager useProgressView:progressView forUploadingAttachment:attachment];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAttachmentUploadCompleted:) name:ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_FINISHED object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAttachmentUploadFailed:) name:ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_FAILED object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAttachmentUploadStarted:) name:ZPNOTIFICATION_ATTACHMENT_FILE_UPLOAD_STARTED object:nil];
        
*/


}

-(void) setShouldObserveDownloads:(BOOL) observeDownloads{
    
    /*
     [ZPFileDownloadManager useProgressView:progressView forDownloadingAttachment:attachment];

     [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAttachmentDownloadCompleted:) name:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FINISHED object:nil];
     [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAttachmentDownloadFailed:) name:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_FAILED object:nil];
     [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAttachmentDownloadStarted:) name:ZPNOTIFICATION_ATTACHMENT_FILE_DOWNLOAD_STARTED object:nil];

     
     */
}

-(void) setShouldObserveDeletions:(BOOL) observeDeletions{
    
    /*
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyAttachmentDeleted:) name:ZPNOTIFICATION_ATTACHMENT_FILE_DELETED object:nil];
     */
}

//TODO: When the view is deallocated, it must unregister from NSNotificationCenter default center and it should unregister the progress views from the upload and download manager.


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
