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

#if (TARGET_IPHONE_SIMULATOR)

// A dummy implementation for runnign in simulator

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

@interface ZPGoodReaderIntegration_saveBackDelegate : NSObject <GoodReaderSaveBackDelegate>

@end

@implementation ZPGoodReaderIntegration_saveBackDelegate

-(void)didFinishReceivingSaveBackFromGoodReaderWithResultCode:(GoodReaderTransferResultCodeEnum)resultCode receivedFilePath:(NSString *)receivedFilePath saveBackTag:(NSData *)saveBackTag{
    
    ZPZoteroAttachment* attachment = [ZPZoteroAttachment attachmentWithKey:[[NSString alloc] initWithData:saveBackTag encoding:NSUTF8StringEncoding]];
    
    NSURL* url = [NSURL URLWithString:[receivedFilePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    DDLogInfo(@"A file %@ as a save back from GoodReader",[url lastPathComponent]);
    
    ZPAppDelegate* appDelegate = (ZPAppDelegate*) [[UIApplication sharedApplication] delegate];
    [appDelegate dismissViewControllerHierarchy];
    [appDelegate.window.rootViewController performSegueWithIdentifier:@"Import" sender:url];
    [ZPFileUploadManager addAttachmentToUploadQueue:attachment withNewFile:url];
    
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

