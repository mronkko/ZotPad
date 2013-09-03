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
#import "CMPopTipView.h"

@interface ZPNoteEditingViewController (){
    UIActionSheet* _confirmDelete;
    NSString* _currentContent;
    ZPZoteroDataObject<ZPZoteroDataObjectWithNote>* _note;
    BOOL _isNew;
    UIViewController<ZPNoteDisplay>* _target;
}

@end

@implementation ZPNoteEditingViewController

@synthesize webView, navigationItem;

static ZPNoteEditingViewController* _instance;

+(ZPNoteEditingViewController*) instance{
    if(_instance == NULL){
        
        _instance =[[UIApplication sharedApplication].delegate.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"NoteEditingViewController"];
    }
    return _instance;
}

-(void) configureWithNote:(ZPZoteroDataObject<ZPZoteroDataObjectWithNote>*) note andTarget:(UIViewController<ZPNoteDisplay>*) target isNew:(BOOL)isNew{

    _note = note;
    _isNew = isNew;
    _target = target;
    _currentContent = note.note==NULL?@"":note.note;
    
    [self configure];
}

- (void) configure{

    if([_note isKindOfClass:[ZPZoteroAttachment class]] || _isNew){
        
        if(_isNew){
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
    
    
    [webView loadHTMLString:[NSString stringWithFormat:@"<html><body onload=\"document.getElementById('content').focus()\"><div id='content' contentEditable='true' style='font-family: Helvetica'>%@</div></body></html>",_currentContent]
                    baseURL:NULL];
    
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

	[self configure];
    // Do any additional setup after loading the view.
    

    // Displaying the keyboard automatically requires iOS 6

    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0) {
        webView.keyboardDisplayRequiresUserAction=NO;
    }
    

}
-(void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [webView stringByEvaluatingJavaScriptFromString:@"document.getElementById('content').focus()"];
}

-(void) viewDidAppear:(BOOL)animated{

    [super viewDidAppear:animated];
    
    // Display an alert explaining that the user needs to tap the note to edit
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 6.0) {

        if([[NSUserDefaults standardUserDefaults] objectForKey:@"hasPresentedNoteHelpPopover"]==NULL){
            
            dispatch_async(dispatch_get_main_queue(), ^{
                CMPopTipView* helpPopUp = [[CMPopTipView alloc] initWithMessage:@"Tap the note to edit"];
                helpPopUp.preferredPointDirection = PointDirectionDown;
                UIBarButtonItem* doneButton = self.navigationItem.rightBarButtonItem;
                UIView* targetView = (UIView *)[doneButton performSelector:@selector(view)];
                [helpPopUp presentPointingAtView:self.webView inView:self.view animated:YES];
                [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:@"hasPresentedNoteHelpPopover"];
            });
        }
    }

}

- (void)viewWillUnload{
    _currentContent = [webView stringByEvaluatingJavaScriptFromString:
                       @"document.getElementById('content').innerHTML"];
    [super viewWillUnload];
    
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)cancel:(id)sender{
    [webView loadHTMLString:@"" baseURL:NULL];
    if(_confirmDelete != nil) [_confirmDelete dismissWithClickedButtonIndex:-1 animated:YES];
    [self dismissModalViewControllerAnimated:YES];
}
-(IBAction)save:(id)sender{

    NSString* noteText = [webView stringByEvaluatingJavaScriptFromString:
                          @"document.getElementById('content').innerHTML"];
    _note.note = noteText;

    [webView loadHTMLString:@"" baseURL:NULL];
    if(_confirmDelete != nil) [_confirmDelete dismissWithClickedButtonIndex:-1 animated:YES];
    [self dismissModalViewControllerAnimated:YES];

    if(_isNew){
        [ZPDatabase createNoteLocally:(ZPZoteroNote*) _note];
        ZPZoteroItem* item = [ZPZoteroItem itemWithKey:_note.parentKey];
        item.notes = [item.notes arrayByAddingObject:_note];
    }
    else if([_note isKindOfClass:[ZPZoteroAttachment class]]){
        [ZPDatabase saveLocallyEditedAttachmentNote:(ZPZoteroAttachment*)_note];
    }
    else{
        [ZPDatabase saveLocallyEditedNote:(ZPZoteroNote*) _note];
    }
    
    [ZPItemDataUploadManager uploadMetadata];
    [_target refreshNotesAfterEditingNote:_note];

}

-(IBAction)deleteNote:(id)sender{
 
    _confirmDelete = [[UIActionSheet alloc] initWithTitle:nil
                                                        delegate:self
                                        cancelButtonTitle: UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? nil : @"Cancel"
                                          destructiveButtonTitle:@"Delete note"
                                               otherButtonTitles:nil];
    [_confirmDelete showFromBarButtonItem:sender animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex{
    
    if(buttonIndex == 0){
        [webView loadHTMLString:@"" baseURL:NULL];
        [self dismissModalViewControllerAnimated:YES];
        
        ZPZoteroItem* item = [ZPZoteroItem itemWithKey:_note.parentKey];
        
        DDLogInfo(@"User tapped delete button for note (%@)", item.itemKey);
        
        NSMutableArray* newNotes = [item.notes mutableCopy];
        [newNotes removeObject:_note];
        item.notes = newNotes;
        
        [ZPDatabase deleteNoteLocally:(ZPZoteroNote*)_note];
        [ZPItemDataUploadManager uploadMetadata];
        
        [_target refreshNotesAfterEditingNote:_note];
    }
    _confirmDelete = nil;
}

-(void) _refreshParent{
}

@end
