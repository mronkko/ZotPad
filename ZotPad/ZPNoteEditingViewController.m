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

static ZPNoteEditingViewController* _instance;

+(ZPNoteEditingViewController*) instance{
    if(_instance == NULL){
        
        _instance =[[UIApplication sharedApplication].delegate.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"NoteEditingViewController"];
    }
    return _instance;
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
    

    // Displaying the keyboard automatically requires iOS 6

    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0) {
        webView.keyboardDisplayRequiresUserAction=NO;
    }
    

}
-(void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    NSString* noteString = note.note;
    if(noteString == NULL) noteString = @"";
    
    [webView loadHTMLString:[NSString stringWithFormat:@"<html><body onload=\"document.getElementById('content').focus()\"><div id='content' contentEditable='true' style='font-family: Helvetica'>%@</div></body></html>",noteString]
                    baseURL:NULL];

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
