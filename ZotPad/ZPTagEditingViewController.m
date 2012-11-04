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
    ZPZoteroItem* _item;
    ZPTagController* _tagDataSource;
}

@end

@implementation ZPTagEditingViewController

@synthesize tableView, navigationBar;

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
    [_tagDataSource prepareToShow];
    self.tableView.dataSource = _tagDataSource;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) setItem:(ZPZoteroItem *)item{
    _item = item;
    _selectedTags = _item.tags;
}
-(ZPZoteroItem*) item{
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


@end
