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

@interface ZPWebDAVAuthenticationViewController : UIViewController <UIWebViewDelegate, NSURLConnectionDelegate>{
}


@property(nonatomic,retain) IBOutlet UIWebView *webView;


+(ZPWebDAVAuthenticationViewController*) instance;
+(BOOL) isDisplaying;
-(IBAction)cancel:(id)sender;
-(void) configureWithURL:(NSURL*)url andAttachment:(ZPZoteroAttachment*)attachment;

@end
