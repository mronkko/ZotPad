//
//  ZPAttachmentFileView.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 3/14/13.
//
//

#import <UIKit/UIKit.h>
#import "ZPCore.h"

@interface ZPAttachmentFileView : UIView

-(id) configureWithAttachment:(ZPZoteroAttachment*) attachment;

// Controls whether there is a semi-transparent overlay over the attachmet icon
// showing the name of the attachment, possible other info, and possible a
// progress bar

// Set to FALSE in item list and to TRUE elsewhere

-(void) setAttachmentInfoVisible:(BOOL) attachmentInfoVisible;

// These funtions set whether the view should respond to upload and download
// notifications and display a progress view.

-(void) setShouldObserveUploads:(BOOL) observeUploads;
-(void) setShouldObserveDownloads:(BOOL) observeDownloads;

-(void) setShouldObserveDeletions:(BOOL) observeDeletions;

@end
