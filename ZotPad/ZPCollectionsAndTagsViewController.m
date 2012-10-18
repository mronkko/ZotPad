//
//  ZPCollectionsAndTagsViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 9/6/12.
//
//

#import "ZPCollectionsAndTagsViewController.h"
#import "ZPCacheStatusToolbarController.h"
#import "ZPHelpPopover.h"
#import "FRLayeredNavigationController.h"
#import "FRLayeredNavigationItem.h"
#import "ZPPreferences.h"
#import "ZPItemListViewController.h"
#import "ZPMasterItemListViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "ZPTagController.h"
#import "ZPItemListViewDataSource.h"

@interface ZPCollectionsAndTagsViewController()

-(void)_configureTagsList;
-(void)_toggleTagSelectionWithAnimationDuration:(float) duration toVisible:(BOOL) visible;
@end
@implementation ZPCollectionsAndTagsViewController{
    UIViewController* _contentRoot;
    BOOL _tagsVisible;
    UITableView* _tagsList;
    ZPTagController* _tagController;

}

@synthesize collectionsView, tagsView, tagsHeader;
@synthesize gearButton, cacheControllerPlaceHolder;
@synthesize headerArrowLeft, headerArrowRight;

-(void) viewDidLoad{

    [super viewDidLoad];

    _contentRoot = [self.storyboard instantiateViewControllerWithIdentifier:@"LibraryAndCollectionList"];

    if([ZPPreferences layeredCollectionsNavigation]){
        [_contentRoot loadView];
        
        //For some reason the view life cycle methods do not get called for the root view.
        
        [_contentRoot viewDidLoad];
        FRLayeredNavigationController* navi = [[FRLayeredNavigationController alloc] initWithRootViewController:_contentRoot
                                                                                                  configuration:^(FRLayeredNavigationItem *item) {
                                                                                                      item.width = 320;
                                                                                                      return;
                                                                                                  }];
        navi.minimumLayerWidth = 240;
        [self setInsetViewController:navi];
    }
    else{
        UINavigationController* navi = [[UINavigationController alloc] initWithRootViewController:_contentRoot];
        [self setInsetViewController:navi];
        
    }
    //TODO: Implement this on iPhone as well.
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        
        //Show Cache controller status, only on iPad
        ZPCacheStatusToolbarController* statusController = [[ZPCacheStatusToolbarController alloc] init];
        cacheControllerPlaceHolder.customView = statusController.view;
        
        UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;
        gearButton.target = root;
        gearButton.action = @selector(showLogView:);
    }
    
    //Set the looks of the tag view
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    CGRect frame = tagsHeader.bounds;
    gradient.frame = frame;
    gradient.colors = [NSArray arrayWithObjects:(id)[[UIColor colorWithRed:239.0/255.0 green:240.0/255.0 blue:243.0/255.0 alpha:1.0] CGColor],
                       (id)[[UIColor colorWithRed:165.0/255.0 green:169.0/255.0 blue:182.0/255.0 alpha:1.0] CGColor],
                       nil];
    
    [tagsHeader.layer insertSublayer:gradient atIndex:0];

}

-(void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];

    [_contentRoot viewDidAppear:animated];

    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        if([[NSUserDefaults standardUserDefaults] objectForKey:@"hasPresentedMainHelpPopover"]==NULL){
            [ZPHelpPopover displayHelpPopoverFromToolbarButton:gearButton];
            [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:@"hasPresentedMainHelpPopover"];
        }
    }
}
-(void) viewWillAppear:(BOOL)animated{
    [_contentRoot viewWillAppear:animated];

}

// On iPhone the item list is shown with a segue

-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    
    //iPhone only
    
    if([segue.identifier isEqualToString:@"PushItemList"]){
        /*
        ZPItemListViewController* target = (ZPItemListViewController*) segue.destinationViewController;
        ZPZoteroDataObject* node = [self->_content objectAtIndex: self.tableView.indexPathForSelectedRow.row];
        
        [ZPItemListViewDataSource instance].libraryID = [node libraryID];
        [ZPItemListViewDataSource instance].collectionKey = [node key];
        
        //Clear search when changing collection. This is how Zotero behaves
        [target clearSearch];
        [target configureView];
         */
        
    }
    
    //iPad only

    if([segue.identifier isEqualToString:@"PushItemsToNavigator"]){
        
        
        ZPMasterItemListViewController* target = (ZPMasterItemListViewController*) segue.destinationViewController;
        target.detailViewController = sender;
        target.tableView.delegate = sender;
        
        target.navigationItem.hidesBackButton = YES;
        target.clearsSelectionOnViewWillAppear = NO;
        
        //Keep the same toolbar
        NSArray* toolBarItems =self.toolbarItems;
        [target setToolbarItems:toolBarItems];
        
        // Get the selected row from the item list
        ZPZoteroItem* selectedItem = [(ZPItemDetailViewController*)sender selectedItem];
        NSInteger index = [[[ZPItemListViewDataSource instance] itemKeysShown] indexOfObject:selectedItem.key];
        NSIndexPath* indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        [target.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionMiddle];
    }
}


- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state) {
            
        case UIGestureRecognizerStateBegan: {
            if(_tagsList == NULL){
                [self _configureTagsList];
            }
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            CGPoint location = [gestureRecognizer translationInView:self.view];
            NSInteger y = (_tagsVisible ? 0: self.insetViewController.view.frame.size.height+1) + location.y;
            y= MAX(0,MIN(self.view.frame.size.height - tagsHeader.frame.size.height,y));
            self.tagsView.frame = CGRectMake(0,
                                             y,
                                             self.tagsView.frame.size.width,
                                             self.tagsView.frame.size.height);
            break;
            
        }
            
        case UIGestureRecognizerStateEnded: {
            
            float v = [gestureRecognizer velocityInView:self.view].y;
            NSInteger y = [gestureRecognizer translationInView:self.view].y;

            if(_tagsVisible){
                //Flick down or move over halfway
                if(v>1000 || y> self.view.frame.size.height/2){
                    [self _toggleTagSelectionWithAnimationDuration:0.5*(1.0-((float) abs(y) /(float)self.view.frame.size.height)) toVisible:FALSE];
                    _tagsVisible = FALSE;
                }
                else{
                    [self _toggleTagSelectionWithAnimationDuration:0.5*((float) abs(y) /(float)self.view.frame.size.height) toVisible:TRUE];
                }
            }
            else{
                //Flick up or move over halfway
                if(v<-1000 || y < - self.view.frame.size.height/2){
                    [self _toggleTagSelectionWithAnimationDuration:0.5*(1.0-((float) abs(y) /(float)self.view.frame.size.height)) toVisible:TRUE];
                    _tagsVisible = TRUE;
                }
                else{
                    [self _toggleTagSelectionWithAnimationDuration:0.5*((float) abs(y) /(float)self.view.frame.size.height) toVisible:FALSE];
                
                }
            }
            
            break;
        }
            
        default:
            break;
    }
}

-(IBAction)toggleTagSelector:(id)sender{

    if(_tagsList == NULL){
        [self _configureTagsList];
    }

    _tagsVisible = ! _tagsVisible;

    [self _toggleTagSelectionWithAnimationDuration:0.5 toVisible:_tagsVisible];
}

-(void)_toggleTagSelectionWithAnimationDuration:(float) duration toVisible:(BOOL)visible{
    
    // animate
    
    if(visible){
        [UIView animateWithDuration:duration animations:^{
            tagsView.frame = self.view.frame;
            UIImage* image = [UIImage imageNamed:@"icon-down-black.png"];
            headerArrowLeft.image = image;
            headerArrowRight.image = image;
        }];
    }
    else{
        [UIView animateWithDuration:duration animations:^{
            tagsView.frame = CGRectMake(0,
                                        self.view.frame.size.height - tagsHeader.frame.size.height+1,
                                        tagsView.frame.size.width,
                                        tagsView.frame.size.height);
            UIImage* image = [UIImage imageNamed:@"icon-up-black.png"];
            headerArrowLeft.image = image;
            headerArrowRight.image = image;
        }
                         completion:^(BOOL finished){
                             [_tagsList removeFromSuperview];
                             _tagsList = NULL;
                         }];

    }
    
}


-(void)_configureTagsList{

    _tagsList = [[UITableView alloc] initWithFrame:CGRectMake(0,
                                                              tagsHeader.frame.size.height+1,
                                                              self.view.frame.size.width,
                                                              self.view.frame.size.height-self.tagsHeader.frame.size.height)
                                             style:UITableViewStylePlain];
    _tagsList.allowsSelection = FALSE;
    _tagsList.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    if(_tagController == NULL){
        _tagController = [[ZPTagController alloc] init];
    }
    
    [_tagController configure];
    [_tagsList setDataSource:_tagController];
    [self.tagsView addSubview:_tagsList];

}

@end
