//
//  ZPNoteEditingViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 10/31/12.
//
//

#import "ZPNoteEditingViewController.h"
#import "ZPFileViewerViewController.h"
#import "ZPItemDataUploadManager.h"

@interface ZPNoteEditingViewController ()


@end

@implementation ZPNoteEditingViewController

@synthesize note, webView, isNewNote, navigationItem;

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
    
    if([note isKindOfClass:[ZPZoteroAttachment class]] || isNewNote){
        
        if(isNewNote){
            self.navigationItem.title = @"New note";
        }
        else{
            self.navigationItem.title = @"Edit note";
        }
        
        if(self.navigationItem.leftBarButtonItems.count == 2){

            UIBarButtonItem* cancelButton = [self.navigationItem.leftBarButtonItems objectAtIndex:0];
            self.navigationItem.leftBarButtonItems = nil;
            self.navigationItem.leftBarButtonItem = cancelButton;
        }
    }
    else{
        self.navigationItem.title = @"Edit note";
        
        if(self.navigationItem.leftBarButtonItems.count != 2){
            UIBarButtonItem* deleteButton = [[UIBarButtonItem alloc] initWithTitle:@"Delete"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(deleteNote:)];
            [deleteButton setTintColor:[UIColor redColor]];
            
            UIBarButtonItem* cancelButton = self.navigationItem.leftBarButtonItem;
            
            NSArray* leftBarButtonItems = [NSArray arrayWithObjects: cancelButton, deleteButton, nil];
            self.navigationItem.leftBarButtonItems = leftBarButtonItems;
            
        }
    }

    
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
    [webView loadHTMLString:@"" baseURL:NULL];
    [self dismissModalViewControllerAnimated:YES];
}
-(IBAction)save:(id)sender{

    NSString* noteText = [webView stringByEvaluatingJavaScriptFromString:
                          @"document.getElementById('content').innerHTML"];
    note.note = noteText;

    [webView loadHTMLString:@"" baseURL:NULL];
    [self dismissModalViewControllerAnimated:YES];

    if(isNewNote){
        [ZPDatabase createNoteLocally:(ZPZoteroNote*) self.note];
        ZPZoteroItem* item = [ZPZoteroItem itemWithKey:note.parentKey];
        item.notes = [item.notes arrayByAddingObject:note];
    }
    else if([note isKindOfClass:[ZPZoteroAttachment class]]){
        [ZPDatabase saveLocallyEditedAttachmentNote:(ZPZoteroAttachment*)note];
    }
    else{
        [ZPDatabase saveLocallyEditedNote:(ZPZoteroNote*) self.note];
    }
    
    [ZPItemDataUploadManager uploadMetadata];
    [_targetViewController refreshNotesAfterEditingNote:self.note];

}

-(IBAction)deleteNote:(id)sender{

    [webView loadHTMLString:@"" baseURL:NULL];
    [self dismissModalViewControllerAnimated:YES];

    ZPZoteroItem* item = [ZPZoteroItem itemWithKey:note.parentKey];
    
    NSMutableArray* newNotes = [NSMutableArray arrayWithArray:item.notes];
    [newNotes removeObject:note];
    item.notes = newNotes;
    
    [ZPDatabase deleteNoteLocally:(ZPZoteroNote*)note];
    [ZPItemDataUploadManager uploadMetadata];

    [_targetViewController refreshNotesAfterEditingNote:self.note];

}

-(void) _refreshParent{
}

@end
