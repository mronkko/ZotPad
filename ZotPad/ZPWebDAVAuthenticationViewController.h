//
//  ZPWebDAVAuthenticationViewController.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 3/7/13.
//
//

#import <UIKit/UIKit.h>
#import "DSActivityView.h"
#import "ZPCore.h"
#import "ZPModalViewController.h"

@interface ZPWebDAVAuthenticationViewController : ZPModalViewController <UIWebViewDelegate, NSURLConnectionDelegate>{
}


@property(nonatomic,retain) IBOutlet UIWebView *webView;


+(void) presentInstanceModallyWithAttachment:(ZPZoteroAttachment*) attachment;
+(BOOL) isPresenting;

-(IBAction)cancel:(id)sender;
-(void) configureWithURL:(NSURL*)url andAttachment:(ZPZoteroAttachment*)attachment;

@end
