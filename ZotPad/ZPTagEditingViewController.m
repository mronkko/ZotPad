//
//  ZPTagEditingViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/3/12.
//
//

#import "ZPTagEditingViewController.h"
#import "ZPTagController.h"

@interface ZPTagEditingViewController (){
    NSArray* _selectedTags;
    ZPZoteroDataObject* _item;
    ZPTagController* _tagDataSource;
    __weak UIPopoverController *myPopover;
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
    return [ZPDatabase tagsForLibrary:_item.libraryID];
}

-(BOOL) isTagSelected:(NSString*)tag{
    return [_selectedTags containsObject:tag];
}

-(void)createTag:(NSString*)tag{
    //Only create the tag if it does not exist
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // make sure it's the right segue if you have more than one in this VC
    if([segue.identifier isEqualToString:@"NewTagPopover"]){
        myPopover = [(UIStoryboardPopoverSegue *)segue popoverController];
    }
}

- (IBAction)showPopover:(id)sender {
    if (myPopover)
        [myPopover dismissPopoverAnimated:YES];
    else
        [self performSegueWithIdentifier:@"NewTagPopover" sender:sender];
}


@end
