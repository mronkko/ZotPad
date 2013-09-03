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
    NSString* _itemKey;
    ZPTagController* _tagDataSource;
    UIPopoverController* newTagPopover;
    UIViewController* newTagDialog;
    NSObject<ZPTagDisplay>* _target;
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

- (void) configureWithItemKey:(NSString*) itemKey andTarget:(UIViewController<ZPTagDisplay>*) target{
    _target = target;
    _selectedTags = [ZPZoteroItem itemWithKey:itemKey].tags;
    _itemKey = itemKey;
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

# pragma mark - IBOutlets

-(IBAction)dismiss:(id)sender{
    NSMutableArray* removedTags = [[NSMutableArray alloc] init];
    NSMutableArray* addedTags = [[NSMutableArray alloc] init];
    
    ZPZoteroItem* item = [ZPZoteroItem itemWithKey:_itemKey];
    
    for(NSString* tag in item.tags){
        if([_selectedTags indexOfObject:tag] == NSNotFound){
            [removedTags addObject:tag];
        }
    }
    for(NSString* tag in _selectedTags){
        if([item.tags indexOfObject:tag] == NSNotFound){
            [addedTags addObject:tag];
        }
    }

    if([removedTags count]>0) [ZPDatabase removeTagsLocally:removedTags toItemWithKey:_itemKey];
    if([addedTags count]>0) [ZPDatabase addTagsLocally:addedTags toItemWithKey:_itemKey];
    
    if([addedTags count]>0 || [removedTags count]>0){
        item.tags = _selectedTags;
        
        
        [_target refreshTagsFor:_itemKey];
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
    
    ZPZoteroItem* item = [ZPZoteroItem itemWithKey:_itemKey];
    
    NSArray* tags = [ZPDatabase tagsForLibrary:item.libraryID];
    
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
        UINavigationBar* naviBar = (UINavigationBar*) [newTagDialog.view viewWithTag:3];
        naviBar.topItem.rightBarButtonItem.target = self;
        naviBar.topItem.rightBarButtonItem.action = @selector(createTag:);
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
