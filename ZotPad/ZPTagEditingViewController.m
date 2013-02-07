//
//  ZPTagEditingViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/3/12.
//
//

#import "ZPTagEditingViewController.h"
#import "ZPTagController.h"
#import "ZPFileViewerViewController.h"
#import "ZPDatabase.h"
#import "ZPItemDataUploadManager.h"

@interface ZPTagEditingViewController (){
    NSArray* _selectedTags;
    ZPZoteroDataObject* _item;
    ZPTagController* _tagDataSource;
    UIPopoverController* newTagPopover;
    UIViewController* newTagDialog;
}


@end

@implementation ZPTagEditingViewController

@synthesize tableView, navigationBar;

static ZPTagEditingViewController* _instance;

+(ZPTagEditingViewController*) instance{
    if(_instance == NULL){
        
        _instance =[[UIApplication sharedApplication].delegate.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"TagEditingViewController"];
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
    
    _tagDataSource = [[ZPTagController alloc] init];
    _tagDataSource.tagOwner = self;
    self.tableView.dataSource = _tagDataSource;
}
-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [_tagDataSource prepareToShow];
    [tableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) setItem:(ZPZoteroDataObject *)item{
    _item = item;
    _selectedTags = _item.tags;
}
-(ZPZoteroDataObject*) item{
    return _item;
}


# pragma mark - IBOutlets

-(IBAction)dismiss:(id)sender{
    NSMutableArray* removedTags = [[NSMutableArray alloc] init];
    NSMutableArray* addedTags = [[NSMutableArray alloc] init];
    
    for(NSString* tag in _item.tags){
        if([_selectedTags indexOfObject:tag] == NSNotFound){
            [removedTags addObject:tag];
        }
    }
    for(NSString* tag in _selectedTags){
        if([_item.tags indexOfObject:tag] == NSNotFound){
            [addedTags addObject:tag];
        }
    }

    if([removedTags count]>0) [ZPDatabase removeTagsLocally:removedTags toItemWithKey:_item.key];
    if([addedTags count]>0) [ZPDatabase addTagsLocally:addedTags toItemWithKey:_item.key];
    
    if([addedTags count]>0 || [removedTags count]>0){
        _item.tags = _selectedTags;
        [_targetViewController refreshTagsFor:_item];
        [ZPItemDataUploadManager uploadMetadata];
    }
    
    [self dismissModalViewControllerAnimated:YES];

}

#pragma mark - ZPTagOwner protocol

-(void) selectTag:(NSString*)tag{
    _selectedTags = [[_selectedTags arrayByAddingObject:tag] sortedArrayUsingSelector:@selector(compare:)];
}
-(void) deselectTag:(NSString*)tag{
    NSMutableArray* temp = [NSMutableArray arrayWithArray:_selectedTags];
    [temp removeObject:tag];
    _selectedTags = temp;
}

-(NSArray*) tags{
    return _selectedTags;
}

-(NSArray*) availableTags{
    //Get the tags for currently visible items
    NSArray* tags = [ZPDatabase tagsForLibrary:_item.libraryID];
    
    for (NSString* tag in [self tags]) {
        if([tags indexOfObject:tag] == NSNotFound){
            tags = [tags arrayByAddingObject:tag];
        }
    }
    return tags;
}

-(BOOL) isTagSelected:(NSString*)tag{
    return [_selectedTags containsObject:tag];
}

-(void)createTag:(UIButton*)source{
    
    NSString* newTag;
    if(newTagPopover){
        newTag = [(UITextField*)[newTagPopover.contentViewController.view viewWithTag:1] text];
        [newTagPopover dismissPopoverAnimated:YES];
        newTagPopover = NULL;
    }
    else if(newTagDialog){
        newTag = [(UITextField*)[newTagDialog.view viewWithTag:1] text];
        [newTagDialog dismissModalViewControllerAnimated:YES];
        newTagDialog = NULL;
    }
    
    newTag = [newTag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(! [newTag isEqualToString:@""]){
        [self selectTag:newTag];
        [_tagDataSource prepareToShow];
        [self.tableView reloadData];
    }
    
    
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // make sure it's the right segue if you have more than one in this VC
    
    //iPad
    if([segue.identifier isEqualToString:@"NewTagPopover"]){
        newTagPopover = [(UIStoryboardPopoverSegue *)segue popoverController];
        [(UIButton*)[newTagPopover.contentViewController.view viewWithTag:2] addTarget:self action:@selector(createTag:) forControlEvents:UIControlEventTouchUpInside];
        [[newTagPopover.contentViewController.view viewWithTag:1] becomeFirstResponder];
    }
    //iPhone
    else if([segue.identifier isEqualToString:@"NewTagDialog"]){
        newTagDialog = [segue destinationViewController];
        [(UIButton*)[newTagDialog.view viewWithTag:2] addTarget:self action:@selector(createTag:) forControlEvents:UIControlEventTouchUpInside];
        [[newTagDialog.view viewWithTag:1] becomeFirstResponder];
    }
}

- (IBAction)showPopover:(id)sender {
    if (newTagPopover){
        [newTagPopover dismissPopoverAnimated:YES];
        newTagPopover = NULL;
    }
    else
        [self performSegueWithIdentifier:@"NewTagPopover" sender:sender];
}


@end
