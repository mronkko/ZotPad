//
//  ZPUserSupport.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 7/25/13.
//
//

#import "ZPUserSupport.h"
#import "UserVoice.h"
#import "UVSession.h"
#import "UVClientConfig.h"
#import "ZPSecrets.h"
#import "ZPCore.h"
#import "ZPAppDelegate.h"

@implementation ZPUserSupport

+(void) openSupportSystemWithArticleID:(NSInteger)articleId fromParentViewController:(UIViewController*)viewController{
        
    if(USERVOICE_API_KEY == nil || USERVOICE_SECRET == nil){
        [[[UIAlertView alloc] initWithTitle:@"Not implemented"
                                    message:@"Feedback and knowledge base are not available in this build because UserVoice key or secret is missing."
                                   delegate:nil
                          cancelButtonTitle:@"Cancel"
                          otherButtonTitles:nil]show];
        
    }
    else{
        UVConfig *config = [UVConfig configWithSite:@"zotpad.uservoice.com"
                                             andKey:(NSString*)USERVOICE_API_KEY
                                          andSecret:(NSString*)USERVOICE_SECRET];
        
        ZPAppDelegate* appDelegate = (ZPAppDelegate*) [[UIApplication sharedApplication] delegate];
        NSArray* logFiles = appDelegate.fileLogger.logFileManager.sortedLogFilePaths;
        
        NSString* logPath = nil;
        NSString* logText = nil;
        
        if(logFiles.count>0){
            logPath = [logFiles objectAtIndex:0];
            
            logText = [NSString stringWithContentsOfFile:logPath
                                                encoding:NSUTF8StringEncoding
                                                   error:NULL];
            NSArray* logLines = [logText componentsSeparatedByString:@"\n"];
            NSInteger logLineCount = logLines.count;
            
            if(logLineCount> 300){
                logLines = [logLines subarrayWithRange:NSMakeRange(logLines.count-300, 300)];
            }
            
            logText =[logLines componentsJoinedByString:@"\n"];
            
            if(logLineCount>300){
                logText = [NSString stringWithFormat:@"%i lines of log (omitting lines 1-%i)\n\n%@",logLineCount,logLineCount-300,logText];
            }
            else{
                logText = [NSString stringWithFormat:@"%i lines of log\n\n%@",logLineCount,logText];
            }
            
        }
        else{
            logText = @"\n\nNo log\n\n";
        }
        
        NSString* technicalInfo = [NSString stringWithFormat:@"\n\n --- Technical info ---\n\n%@ %@ (build %@)\n%@ (iOS %@)\nuserID: %@\nAPI key: %@\n\n --- Settings ----\n\n%@\n\n --- Application log ----\n\n%@",
                                   [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"],
                                   [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                                   [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                                   [[UIDevice currentDevice] model],
                                   [[UIDevice currentDevice] systemVersion],
                                   [ZPPreferences userID],
                                   [ZPPreferences OAuthKey],
                                   [ZPPreferences preferencesAsDescriptiveString],
                                   logText];
        
        
        NSMutableArray* attachments = [[NSMutableArray alloc] init];
        
        //If we have a log file, include that
        if(logPath != nil){
            [attachments addObject:logPath];
        }
        
        if([ZPPreferences includeDatabaseWithSupportRequest]){
            [attachments addObject:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"zotpad.sqlite"]];
        }
        // Do we want to include a file list
        
        if([ZPPreferences includeFileListWithSupportRequest]){
            NSString* documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
            NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:NULL];
            
            NSString* fileListFile = [NSTemporaryDirectory() stringByAppendingPathComponent: @"files.txt"];
            NSString* fileListString  = [directoryContent componentsJoinedByString:@"\n"];
            
            [fileListString writeToFile:fileListFile
                             atomically:NO
                               encoding:NSStringEncodingConversionAllowLossy
                                  error:nil];
            
            [attachments addObject:fileListFile];
            
        }
        
        config.attachmentFilePaths = attachments;
        config.extraTicketInfo = technicalInfo;
        
        if(articleId == -1)
            [UserVoice presentUserVoiceInterfaceForParentViewController:viewController andConfig:config];
        else
            [UserVoice presentUserVoiceKnowledgeBaseArticleForParentViewController:viewController andArticleId:articleId andConfig:config];
    }
    
}

+(void) openSupportSystemFromParentViewController:(UIViewController*)viewController{
    [self openSupportSystemWithArticleID:-1 fromParentViewController:viewController];
}

@end
