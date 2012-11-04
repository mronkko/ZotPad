//
//  ZPNoteEditingViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 10/31/12.
//
//

#import "ZPNoteEditingViewController.h"

@interface ZPNoteEditingViewController ()

@end

@implementation ZPNoteEditingViewController

@synthesize note, webView;

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
    
    //http://ios-blog.co.uk/tutorials/rich-text-editing-a-simple-start-part-1/
    
    if(note.note == NULL) note.note = @"";
    
    [webView loadHTMLString:[NSString stringWithFormat:@"<html><body><div id='content' contentEditable='true' style='font-family: Helvetica'>%@</div></body></html>",note.note]
                    baseURL:NULL];
    

}
- (void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];

    // Displaying the keyboard automatically requires iOS 6
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0) {
        webView.keyboardDisplayRequiresUserAction=NO;
        [webView stringByEvaluatingJavaScriptFromString:@"if(document.getElementById('content') != null) { document.getElementById('content').focus() }"];
        
    }
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)cancel:(id)sender{
    [self dismissModalViewControllerAnimated:YES];
}
-(IBAction)save:(id)sender{
    [self dismissModalViewControllerAnimated:YES];
}

@end
