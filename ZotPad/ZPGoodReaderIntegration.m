//
//  ZPGoodReaderIntegration.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 4/27/13.
//
//

#import "ZPGoodReaderIntegration.h"
#import "ZPAppDelegate.h"
#import "ZPFileUploadManager.h"
#import "ZPFileImportViewController.h"

#if (TARGET_IPHONE_SIMULATOR)

// A dummy implementation for running in simulator

@implementation ZPGoodReaderIntegration

+(BOOL) takeOverIncomingURLRequest:(NSURL*) url{
    return FALSE;
}
+(BOOL) isGoodReaderAppInstalled{
    return FALSE;
}
+(void) sendAttachmentToGoodReader:(ZPZoteroAttachment*) attachment{}

@end

#else

#import "SendToGoodReader.h"

@interface ZPGoodReaderIntegration_saveBackDelegate : NSObject <GoodReaderSaveBackDelegate, UIAlertViewDelegate>{
    UIAlertView* _progressDialog;
    unsigned long long _incomingFileSize;
}

@end

@implementation ZPGoodReaderIntegration_saveBackDelegate

-(void)didFinishReceivingSaveBackFromGoodReaderWithResultCode:(GoodReaderTransferResultCodeEnum)resultCode receivedFilePath:(NSString *)receivedFilePath saveBackTag:(NSData *)saveBackTag{

    // Dismiss the progress dialog
    
    if(_progressDialog != nil){
        [_progressDialog dismissWithClickedButtonIndex:0 animated:NO];
        _progressDialog = nil;
    }

    if(resultCode == kGoodReaderTransferResult_Success){
        ZPZoteroAttachment* attachment = [ZPZoteroAttachment attachmentWithKey:[[NSString alloc] initWithData:saveBackTag encoding:NSUTF8StringEncoding]];
    
        DDLogInfo(@"An attachment %@ as a save back from GoodReader",attachment.itemKey);
        [ZPFileImportViewController presentInstanceModallyWithAttachment:attachment];
    
        NSURL* url = [NSURL URLWithString:[receivedFilePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];

        [ZPFileUploadManager addAttachmentToUploadQueue:attachment withNewFile:url];
    }
    else{
        DDLogInfo(@"Save back from GoodReader failed or was canceled: %i", resultCode);
    }
    
}

-(void) willStartReceivingSaveBackFromGoodReader:(UInt64)estimatedFileSize{
    DDLogInfo(@"Started receiving data (%lli bytes) from GoodReader", estimatedFileSize);

// If the estimated file size is more than a megabyte, show a progress view
// TODO: Refactor for ZotPad 2.0
    if(estimatedFileSize > 1048576){
        _progressDialog = [[UIAlertView alloc] initWithTitle:@"Receiving file (0%)"
                                                     message:@""
                                                    delegate:self
                                           cancelButtonTitle:@"Cancel"
                                           otherButtonTitles:nil];
        _incomingFileSize = estimatedFileSize;
        
        [_progressDialog show];
    }
}

-(void) saveBackProgressUpdate:(UInt64)totalBytesReceived{
    if(_progressDialog != nil){
        _progressDialog.title = [NSString stringWithFormat:@"Receiving file (%lli%%)", MIN(100,totalBytesReceived*100/_incomingFileSize)];
    }
}

-(void) alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex{
    _progressDialog = nil;
    
    if([GoodReaderTransferClient isCurrentlyReceiving]){
        [GoodReaderTransferClient cancelSendingOrReceivingWithoutNotifyingTheDelegate];
    }
}

@end

@implementation ZPGoodReaderIntegration

static ZPGoodReaderIntegration_saveBackDelegate* _delegateInstance;

+(BOOL)takeOverIncomingURLRequest:(NSURL*) url{
    if(_delegateInstance == nil) _delegateInstance = [[ZPGoodReaderIntegration_saveBackDelegate alloc] init];
    return [ GoodReaderTransferClient takeOverIncomingURLRequest:url optionalSaveBackDelegate:_delegateInstance];
}
+(BOOL)isGoodReaderAppInstalled{
    return [GoodReaderTransferClient isGoodReaderAppInstalled];
}

+(void) sendAttachmentToGoodReader:(ZPZoteroAttachment*) attachment{
    
    [GoodReaderTransferClient sendFiles:[NSDictionary dictionaryWithObjectsAndKeys:attachment.fileSystemPath, kSendToGoodReader_ParamKey_ObjectToSend,
                                         [attachment.itemKey dataUsingEncoding:NSUTF8StringEncoding], kSendToGoodReader_ParamKey_SaveBackTag, nil]
                       transferDelegate:nil
                     optionalResultCode:nil];
    
    //Store the version identifier. This is later used to upload modified files to Zotero

    //TODO: Refactor, this is duplicate code
    
    if( attachment.versionIdentifier_local == NULL){
        if(attachment.versionIdentifier_server == NULL){
            DDLogCError(@"Server version identifier for attachment %@ was null",attachment.key);
            attachment.versionIdentifier_server = [ZPZoteroAttachment md5ForFileAtPath:attachment.fileSystemPath_original];
            //[NSException raise:@"Attachment version identifier cannot be null" format:@"Server version identifier for attachment %@ was null",_activeAttachment.key];
        }
        attachment.versionIdentifier_local = attachment.versionIdentifier_server;
    }
    
    [ZPDatabase writeVersionInfoForAttachment:attachment];

}

@end

#endif

