//
//  ZPWebDAVAuthenticationViewController.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 3/7/13.
//
//

#import "ZPWebDAVAuthenticationViewController.h"
#import "ZPFileChannel_WebDAV.h"

@interface ZPWebDAVAuthenticationViewController (){
    DSActivityView* _activityView;
    NSURL* _originalURL;
    ZPZoteroAttachment* _attachment;
    BOOL _hasRedirected;
    
    BOOL _needsSSL;
    
}

@end

@implementation ZPWebDAVAuthenticationViewController

static ZPWebDAVAuthenticationViewController* _instance;

+(ZPWebDAVAuthenticationViewController*) instance{
    if(_instance == nil){
        UIViewController *rootController = [[[[UIApplication sharedApplication]delegate] window] rootViewController];
        _instance = [rootController.storyboard instantiateViewControllerWithIdentifier:@"WebDAVRedirectDialog"];
    }
    return _instance;
}

+(BOOL) isDisplaying{
    return _instance != nil;
}


-(void) configureWithURL:(NSURL*)url andAttachment:(ZPZoteroAttachment*)attachment{
    _originalURL = url;
    _attachment = attachment;
    _hasRedirected = false;
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
	// Do any additional setup after loading the view.
    
}

-(void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    NSURLRequest* request = [NSURLRequest requestWithURL:_originalURL];
    [self.webView loadRequest:request];

}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)cancel:(id)sender{
    
    [self dismissModalViewControllerAnimated:YES];

    //Clear the instance to save memory
    _instance = nil;
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{

    if(_needsSSL) return false;
    
    if([request.URL isEqual:_originalURL]){
        
        //We should be authenticated now
        
        if(_hasRedirected){
            [self dismissModalViewControllerAnimated:YES];
            
            //Clear the instance to save memory
            _instance = nil;
            
            //Retry the download
            [[ZPFileChannel_WebDAV fileChannelForAttachment:_attachment] startDownloadingAttachment:_attachment];
            
            return TRUE;
        }
    }
    else{
        _hasRedirected = TRUE;
    }
    
    if(_activityView == NULL){
        _activityView = [DSBezelActivityView newActivityViewForView:webView];
    }
    
    return TRUE;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView{
    if(_activityView != NULL){
        [DSBezelActivityView removeViewAnimated:YES];
        [[self webView] setUserInteractionEnabled:TRUE];
        _activityView = NULL;
    }
}

- (void)webViewDidStartLoad:(UIWebView *)webView{
    DDLogInfo(@"Started loading WebDAV authentication view");
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{

    DDLogWarn(@"Loading WebDAV authentication view failed with error %@", error);
    
    //SSL problems
    
    if(error.code == -1202){
        _needsSSL = TRUE;
        NSURLRequest* request = [[NSURLRequest alloc] initWithURL:_originalURL];
        NSURLConnection* connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    }
}

#pragma mark - NSURLConnectionDelegate

/*
 
 This disables SSL certificate checking. This code will only run if the user has
 already indicated that he does not care about security by disabling SSL 
 checking in the WebDAV file channel, so we might as well disable it here'
 automatically.
 
*/

-(void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        DDLogWarn(@"Trusting connection to host %@", challenge.protectionSpace.host);
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    }
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)pResponse {
    _needsSSL = FALSE;
    [connection cancel];
    [self.webView loadRequest:[[NSURLRequest alloc] initWithURL:_originalURL]];
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    DDLogWarn(@"Connection failed with error %@", error);
}
-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    DDLogInfo(@"did receive data");
}
-(void)connectionDidFinishLoading:(NSURLConnection *)connection{
    DDLogInfo(@"did finish loading");
}

@end
