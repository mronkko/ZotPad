//
//  ZPFileViewerViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 10/27/12.
//
//

#import "ZPFileViewerViewController.h"

//User interface
#import <QuartzCore/QuartzCore.h>
#import "CMPopTipView.h"
#import "ZPFileViewerNavigationViewController.h"
#import "ZPQLPreviewControllerViewController.h"
#import "ZPTagController.h"
#import "NSString_stripHtml.h"
#import "ZPTagEditingViewController.h"
#import "ZPNoteEditingViewController.h"

#import "ZPUtils.h"

//Unzipping and base64 decoding
#import "ZipArchive.h"
#import "NSString+Base64.h"


@interface ZPFileViewerViewController (){
    //An ugly way to load table view cells for tags twice so that they are sized correctly
    NSArray* _tagButtonsForAttachment;
    NSArray* _tagButtonsForParent;
}

-(void)_togglePullPane:(UIView*)pane duration:(float) duration toVisible:(BOOL)visible;
-(void)_moveView:(UIView*) view horizontallyBy:(float) amount;
-(NSInteger) _xCoordinateForView:(UIView*) view isVisible:(BOOL) visible;
-(void) _segmentChanged:(UISegmentedControl*) source;
-(void) _toggleArrows;
-(void) _updateTitleAndStarButton;
-(void) _updateLeftPullPane;

@end


@implementation ZPFileViewerViewController

static ZPFileViewerViewController* _instance;

+(ZPFileViewerViewController*) instance{
    if(_instance == NULL){
        
        _instance =[[UIApplication sharedApplication].delegate.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"FileViewerViewController"];
    }
    return _instance;
}

+(void) presentWithAttachment:(ZPZoteroAttachment*)attachment{
    if ([NSThread isMainThread]){

        UIViewController* root =[UIApplication sharedApplication].delegate.window.rootViewController;
        
        
        // Only show the viewer if there is no modal view controller visible
        if(root.presentedViewController == nil){
            ZPFileViewerViewController* vc = [self instance];
            [vc addAttachmentToViewer:attachment];
            [root presentModalViewController:vc animated:YES];
        }
    }
    else{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentWithAttachment:attachment];
        });
    }
}
@synthesize navigationBar, leftPullPane, leftPullTab, rightPullPane, rightPullTab, navigationArrows, notesAndTagsTable;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _attachments = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _attachments = [[NSMutableArray alloc] init];
        _previewControllers = [[NSMutableArray alloc] init];
    }
    return self;
    
}
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    // Disable the right pull pane for now. It will be used for the annotation tools in the future.
    
    [self.rightPullTab removeFromSuperview];
    self.rightPullTab = NULL;
    [self.rightPullPane removeFromSuperview];
    self.rightPullPane = NULL;
    
    
    // Set up buttons
    
    UIBarButtonItem* doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                target:self
                                                                                action:@selector(dismiss:)];
    
    navigationArrows = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:[UIImage imageNamed:@"left"],[UIImage imageNamed:@"right"], nil]];
    navigationArrows.segmentedControlStyle = UISegmentedControlStyleBar;

    //Need custome graphics because the segments are inconsistently colored because they are unselected
    
    [navigationArrows setBackgroundImage:[UIImage imageNamed:@"barbutton_image_up_state"] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [navigationArrows setBackgroundImage:[UIImage imageNamed:@"barbutton_image_down_state"] forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];

    [navigationArrows setWidth:40 forSegmentAtIndex:0];
    [navigationArrows setWidth:40 forSegmentAtIndex:1];
    
    [navigationArrows addTarget:self action:@selector(_segmentChanged:) forControlEvents:UIControlEventValueChanged];
    
    UIBarButtonItem* forwardAndBackButtons = [[UIBarButtonItem alloc] initWithCustomView:navigationArrows];
    
    UIBarButtonItem* presentAllFilesButton = NULL;
    
    //iPad and iOS 6 have "expose" function
    /*
     //Not implemented yet
     if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0 &&
     [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad){
     presentAllFilesButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"more"]
     style:UIBarButtonItemStylePlain
     target:self
     action:@selector(presentAllFiles:)];
     }
     */
    
    UIBarButtonItem* spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    spacer.width = 20;
    
    
    
    self.navigationItem.leftBarButtonItems = [NSArray arrayWithObjects:doneButton, spacer, forwardAndBackButtons,presentAllFilesButton, nil];
    
    _starButton = [[ZPStarBarButtonItem alloc] init];
    
    //Show tool tip about stars
    
    if([[NSUserDefaults standardUserDefaults] objectForKey:@"hasPresentedStarButtonHelpPopover"]==NULL){
        CMPopTipView* helpPopUp = [[CMPopTipView alloc] initWithMessage:@"Use the star button to add the item to favorites"];
        [helpPopUp presentPointingAtBarButtonItem:_starButton animated:YES];
        [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:@"hasPresentedStarButtonHelpPopover"];
    }
    
    UIBarButtonItem* actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionButtonPressed:)];
    
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:actionButton, _starButton, nil];
    self.navigationItem.title = @"File viewer";
    
    [self.navigationBar pushNavigationItem:self.navigationItem animated:NO];
    
    
    //Configure the QuickLook attachment viewer
    
    _itemViewers = [[ZPFileViewerNavigationViewController alloc] init];
    _itemViewers.navigationBarHidden = YES;
    
    [self setInsetViewController:_itemViewers];
    
    //Hide both pull tabs
    
    if(rightPullPane!=NULL){
        rightPullPane.frame = CGRectMake(rightPullPane.frame.origin.x + rightPullPane.frame.size.width,
                                         rightPullPane.frame.origin.y,
                                         rightPullPane.frame.size.width,
                                         rightPullPane.frame.size.height);
        
        rightPullTab.frame = CGRectMake(rightPullTab.frame.origin.x + rightPullPane.frame.size.width,
                                        rightPullTab.frame.origin.y,
                                        rightPullTab.frame.size.width,
                                        rightPullTab.frame.size.height);
    }
    
    leftPullPane.frame = CGRectMake(leftPullPane.frame.origin.x - leftPullPane.frame.size.width,
                                    leftPullPane.frame.origin.y,
                                    leftPullPane.frame.size.width,
                                    leftPullPane.frame.size.height);
    
    leftPullTab.frame = CGRectMake(leftPullTab.frame.origin.x - leftPullPane.frame.size.width,
                                   leftPullTab.frame.origin.y,
                                   leftPullTab.frame.size.width,
                                   leftPullTab.frame.size.height);
    leftPullTab.alpha = .30;
    
}
-(void) _toggleArrows{
    [navigationArrows setEnabled:_activeAttachmentIndex>0 forSegmentAtIndex:0];
    [navigationArrows setEnabled:_activeAttachmentIndex<([_attachments count]-1) forSegmentAtIndex:1];
}

-(void) viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:animated];
    
    //Configure the pull panes
    
    for(NSInteger index =0; index <(1+(rightPullPane!=NULL));++index){
        
        UIView* pane;
        UIView* pullTab;
        
        NSInteger x0;
        NSInteger x1;
        NSInteger x2;
        
        if(index == 0){
            pane = self.leftPullPane;
            pullTab = self.leftPullTab;
            x0=0;
            x1=pane.frame.size.width;
            x2=x1 + pullTab.frame.size.width;
        }
        else{
            pane = self.rightPullPane;
            pullTab = self.rightPullTab;
            x0=pane.frame.size.width;
            x1=0;
            x2=x1 - pullTab.frame.size.width;
        }
        
        
        UIBezierPath* shadowPath = [UIBezierPath bezierPath];
        
        NSInteger y0 = 0;
        NSInteger y1 = pullTab.frame.origin.y - pane.frame.origin.y;
        NSInteger y2 = y1 + pullTab.frame.size.width;
        NSInteger y3 = y1 + pullTab.frame.size.height - pullTab.frame.size.width;
        NSInteger y4 = y1 + pullTab.frame.size.height;
        NSInteger y5 = pane.frame.size.height;
        
        [shadowPath moveToPoint:CGPointMake(x0, y0) ];
        [shadowPath addLineToPoint:CGPointMake(x1, y0) ];
        [shadowPath addLineToPoint:CGPointMake(x1, y1) ];
        
        [shadowPath addCurveToPoint:CGPointMake(x2, y2)
                      controlPoint1:CGPointMake(x1, y3)
                      controlPoint2:CGPointMake(x2, y2)];
        
        [shadowPath addLineToPoint:CGPointMake(x2, y3) ];
        
        [shadowPath addCurveToPoint:CGPointMake(x1, y4)
                      controlPoint1:CGPointMake(x2, y4)
                      controlPoint2:CGPointMake(x1, y3)];
        
        [shadowPath addLineToPoint:CGPointMake(x1, y5)];
        [shadowPath addLineToPoint:CGPointMake(x0, y5)];
        
        [shadowPath closePath];
        
        pane.layer.shadowPath = shadowPath.CGPath;
        pane.layer.shadowColor = [UIColor blackColor].CGColor;
        pane.layer.shadowOpacity = 0.5;
        pane.layer.shadowRadius = 10.0;
        pane.layer.shouldRasterize = YES;
        pane.layer.rasterizationScale = [UIScreen mainScreen].scale;
        
        //Clip the pull tabs
        
        UIBezierPath* clipPath = [UIBezierPath bezierPath];
        
        NSInteger ty0 = 0;
        NSInteger ty1 = pullTab.frame.size.width;
        NSInteger ty2 = pullTab.frame.size.height-pullTab.frame.size.width;
        NSInteger ty3 = pullTab.frame.size.height;
        
        NSInteger tx0;
        NSInteger tx1;
        
        if(index == 0){
            tx0 = 0;
            tx1 = pullTab.frame.size.width;
        }
        else{
            tx1 = 0;
            tx0 = pullTab.frame.size.width;
        }
        
        [clipPath moveToPoint:CGPointMake(tx0, ty0) ];
        
        [clipPath addCurveToPoint:CGPointMake(tx1, ty1)
                    controlPoint1:CGPointMake(tx0, ty1)
                    controlPoint2:CGPointMake(tx1, ty0)];
        
        [clipPath addLineToPoint:CGPointMake(tx1, ty2) ];
        
        [clipPath addCurveToPoint:CGPointMake(tx0, ty3)
                    controlPoint1:CGPointMake(tx1, ty3)
                    controlPoint2:CGPointMake(tx0, ty2)];
        
        [clipPath closePath];
        
        CAShapeLayer* shapeMask = [[CAShapeLayer alloc] initWithLayer:pullTab.layer];
        shapeMask.path = clipPath.CGPath;
        pullTab.layer.mask = shapeMask;
        
    }
    
    // Configure the previews
    
    [_itemViewers setViewControllers:_previewControllers animated:NO];
    
    //Configure arrows and title
    
    [self _toggleArrows];
    [self _updateTitleAndStarButton];
    [self _updateLeftPullPane];
}


- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    UIView* pane = self.leftPullPane;
    UIView* pullTab = self.leftPullTab;
    NSInteger x0=0;
    NSInteger x1=pane.frame.size.width;
    NSInteger x2=x1 + pullTab.frame.size.width;
    
    // Update the shadow path
    CGPathRef oldShadowPath = pane.layer.shadowPath;
    
    if (oldShadowPath)
        CFRetain(oldShadowPath);
    
    UIBezierPath* shadowPath = [UIBezierPath bezierPath];
    
    NSInteger newHeight;
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    
    if(toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight){
        newHeight = (int) screenRect.size.width - 20;
    }
    else{
        newHeight = (int) screenRect.size.height - 20;
    }
    
    NSInteger y0 = 0;
    NSInteger y1 = (newHeight-pullTab.frame.size.height)/2;
    NSInteger y2 = y1 + pullTab.frame.size.width;
    NSInteger y3 = y1 + pullTab.frame.size.height - pullTab.frame.size.width;
    NSInteger y4 = y1 + pullTab.frame.size.height;
    NSInteger y5 = newHeight;
    
    [shadowPath moveToPoint:CGPointMake(x0, y0) ];
    [shadowPath addLineToPoint:CGPointMake(x1, y0) ];
    [shadowPath addLineToPoint:CGPointMake(x1, y1) ];
    
    [shadowPath addCurveToPoint:CGPointMake(x2, y2)
                  controlPoint1:CGPointMake(x1, y3)
                  controlPoint2:CGPointMake(x2, y2)];
    
    [shadowPath addLineToPoint:CGPointMake(x2, y3) ];
    
    [shadowPath addCurveToPoint:CGPointMake(x1, y4)
                  controlPoint1:CGPointMake(x2, y4)
                  controlPoint2:CGPointMake(x1, y3)];
    
    [shadowPath addLineToPoint:CGPointMake(x1, y5)];
    [shadowPath addLineToPoint:CGPointMake(x0, y5)];
    
    [shadowPath closePath];
    
    pane.layer.shadowPath = shadowPath.CGPath;
    
    if (oldShadowPath) {
        [pane.layer addAnimation:((^ {
            CABasicAnimation *transition = [CABasicAnimation animationWithKeyPath:@"shadowPath"];
            transition.fromValue = (__bridge id) oldShadowPath;
            transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            transition.duration = duration;
            return transition;
        })()) forKey:@"transition"];
        CFRelease(oldShadowPath);
    }
    
    //Animate the placeholderview
    BOOL reposition = UIInterfaceOrientationIsLandscape(toInterfaceOrientation) && _leftPaneVisible;
    
    self.placeholderView.frame = CGRectMake(reposition?leftPullPane.frame.size.width:0,
                                            self.placeholderView.frame.origin.y,
                                            (UIInterfaceOrientationIsLandscape(toInterfaceOrientation)?[[UIScreen mainScreen] bounds].size.height:[[UIScreen mainScreen] bounds].size.width)-(reposition?leftPullPane.frame.size.width:0),
                                            self.placeholderView.frame.size.height);
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Managing the displayed items

-(void) addAttachmentToViewer:(ZPZoteroAttachment*)attachment{
    
    //Do not add the object if it already exists
    
    NSInteger attachmentIndex = [_attachments indexOfObject:attachment];
    
    if(attachmentIndex != NSNotFound){
        if([_attachments lastObject]!=attachment){
            [_attachments removeObjectAtIndex:attachmentIndex];
            [_attachments addObject:attachment];
            
            [_previewControllers addObject:[_previewControllers objectAtIndex:attachmentIndex]];
            [_previewControllers removeObjectAtIndex:attachmentIndex];
        }
    }
    else{
        // Imported URLs need to be unzipped
        if(attachment.linkMode == LINK_MODE_IMPORTED_URL && ([attachment.contentType isEqualToString:@"text/html"] ||
                                                             [attachment.contentType isEqualToString:@"application/xhtml+xml"])){
            
            //TODO: Make sure that this tempdir is cleaned at some point (Maybe refactor this into ZPZoteroAttachment)
            
            NSString* tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:attachment.key];
            
            if([[NSFileManager defaultManager] fileExistsAtPath:tempDir]){
                [[NSFileManager defaultManager] removeItemAtPath:tempDir error:NULL];
            }
            [[NSFileManager defaultManager] createDirectoryAtPath:tempDir
                                      withIntermediateDirectories:YES attributes:nil error:nil];
            ZipArchive* zipArchive = [[ZipArchive alloc] init];
            [zipArchive UnzipOpenFile:attachment.fileSystemPath];
            [zipArchive UnzipFileTo:tempDir overWrite:YES];
            [zipArchive UnzipCloseFile];
            
            //List the unzipped files and decode them
            
            NSArray* files = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:tempDir error:NULL];
            
            for (NSString* file in files){
                // The filenames end with %ZB64, which needs to be removed
                NSString* toBeDecoded = [file substringToIndex:[file length] - 5];
                NSString* decodedFilename = [toBeDecoded base64DecodedString];
                
                [[NSFileManager defaultManager] moveItemAtPath:[tempDir stringByAppendingPathComponent:file] toPath:[tempDir stringByAppendingPathComponent:decodedFilename] error:NULL];
                
            }
        }
        [_attachments addObject:attachment];
        ZPQLPreviewControllerViewController* newPreviewController = [[ZPQLPreviewControllerViewController alloc] init];
        newPreviewController.dataSource = self;
        [_previewControllers addObject:newPreviewController];
    }
    
    _activeAttachmentIndex = [_attachments count]-1;
    
    
}

-(void) _updateTitleAndStarButton{
    ZPZoteroItem* parent = [ZPZoteroItem itemWithKey:[(ZPZoteroAttachment*) [_attachments objectAtIndex:_activeAttachmentIndex] parentKey]];
    self.navigationBar.topItem.title = parent.shortCitation;
    [self.starButton configureWithItemKey:parent.itemKey];
}

-(void) _updateLeftPullPane{
    _tagButtonsForAttachment = NULL;
    _tagButtonsForParent = NULL;
    [self.notesAndTagsTable reloadData];
}

#pragma mark - Button actions

-(IBAction) dismiss:(id)source{
    [_attachmentInteractionController.actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
    [self dismissModalViewControllerAnimated:YES];
}

// This is not currently in use because there is no practical way to detect taps
// on QLPreviewController. This will be fully implemented when a real PDF library
// is included in ZotPad

- (IBAction) toggleNavigationBar:(id)sender{
    
    BOOL isHidden = self.navigationBar.hidden;
    [UIView animateWithDuration:0.2f
                     animations:^{
                         // animations...
                         if(isHidden){
                             self.navigationBar.hidden = FALSE;
                             self.navigationBar.alpha = 1;
                         }
                         else{
                             self.navigationBar.alpha = 0;
                         }
                     }
                     completion:^(BOOL finished){
                         if(!isHidden){
                             self.navigationBar.hidden = TRUE;
                         }
                     }
     ];
}

- (IBAction) actionButtonPressed:(id)sender{
    
    ZPZoteroAttachment* currentAttachment = [_attachments objectAtIndex:_activeAttachmentIndex];
    if(_attachmentInteractionController == NULL)  _attachmentInteractionController = [[ZPAttachmentFileInteractionController alloc] init];
    
    [_attachmentInteractionController setItemKey:nil];
    [_attachmentInteractionController setAttachment:currentAttachment];
    
    [_attachmentInteractionController presentOptionsMenuFromBarButtonItem:sender];
}

-(void) _segmentChanged:(UISegmentedControl*) source{
    if(source.selectedSegmentIndex==0) [self previous:source];
    else [self next:source];
    source.selectedSegmentIndex = UISegmentedControlNoSegment;
}


- (IBAction) next:(id)sender{
    [_attachmentInteractionController.actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
    _activeAttachmentIndex++;
    [self _toggleArrows];
    [self _updateTitleAndStarButton];
    [self _updateLeftPullPane];
    [_itemViewers pushViewController:[_previewControllers objectAtIndex:_activeAttachmentIndex] animated:YES];
}

- (IBAction) previous:(id)sender{
    [_attachmentInteractionController.actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
    _activeAttachmentIndex--;
    [self _toggleArrows];
    [self _updateTitleAndStarButton];
    [self _updateLeftPullPane];
    [_itemViewers popViewControllerAnimated:YES];
}

//TODO: Implement for expose effect

- (IBAction) presentAllFiles:(id)sender{
    
}

// Hiding and showing the pull panes

- (void)handlePanGestureOnPullPane:(UIPanGestureRecognizer *)gestureRecognizer
{
    UIView* pullPane;
    UIView* pullTab;
    BOOL isRight;
    
    if(gestureRecognizer.view == self.leftPullPane || gestureRecognizer.view == self.leftPullTab){
        pullTab= self.leftPullTab;
        pullPane= self.leftPullPane;
        isRight = NO;
    }
    else{
        pullTab= self.rightPullTab;
        pullPane= self.rightPullPane;
        isRight = YES;
    }
    
    switch (gestureRecognizer.state) {
            
        case UIGestureRecognizerStateBegan: {
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            CGPoint location = [gestureRecognizer translationInView:gestureRecognizer.view];
            
            [self _moveView:pullTab horizontallyBy:location.x];
            [self _moveView:pullPane horizontallyBy:location.x];
            
            break;
            
        }
            
        case UIGestureRecognizerStateEnded: {
            
            
            float v = [gestureRecognizer velocityInView:self.view].x;
            
            //Toggle based on velocity
            
            BOOL toVisible;
            
            if(ABS(v)>1000){
                toVisible = isRight?v<0:v>0;
            }
            
            //Toggle based on position, is the view closer to close position
            else{
                toVisible = ABS([self _xCoordinateForView:pullPane isVisible:YES] - pullPane.frame.origin.x) <
                ABS([self _xCoordinateForView:pullPane isVisible:NO] - pullPane.frame.origin.x);
            }
            
            float time = ABS(pullPane.frame.origin.x-[self _xCoordinateForView:pullPane isVisible:toVisible])/1000.0f;
            
            [self _togglePullPane:pullPane duration:time toVisible:toVisible];
            break;
        }
            
        default:
            break;
    }
}

-(IBAction)togglePullPane:(UIGestureRecognizer*)sender{
    if(sender.view == self.leftPullTab){
        [self _togglePullPane:self.leftPullPane duration:leftPullPane.frame.size.width/1000.0f toVisible:!_leftPaneVisible];
    }
    else{
        [self _togglePullPane:self.rightPullPane duration:rightPullPane.frame.size.width/1000.0f toVisible:!_rightPaneVisible];
    }
}

-(void)_togglePullPane:(UIView*)pane duration:(float) duration toVisible:(BOOL)visible{
    
    //If the view is alreay in the correct place, the duration would be zero
    
    if(duration!=0){
        
        [UIView animateWithDuration:duration animations:^{
            UIView* pullTab;
            if(pane == self.leftPullPane) pullTab = self.leftPullTab;
            else pullTab = self.rightPullTab;
            
            pane.frame = CGRectMake([self _xCoordinateForView:pane isVisible:visible],
                                    pane.frame.origin.y,
                                    pane.frame.size.width,
                                    pane.frame.size.height);
            
            pullTab.frame = CGRectMake([self _xCoordinateForView:pullTab isVisible:visible],
                                       pullTab.frame.origin.y,
                                       pullTab.frame.size.width,
                                       pullTab.frame.size.height);
            
            if(visible){
                pullTab.alpha = 1;
            }
            else{
                pullTab.alpha = .30;
            }
         
            
        } completion:^(BOOL finished) {
            if(pane==leftPullPane && UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation])){
                self.placeholderView.frame = CGRectMake(visible?leftPullPane.frame.size.width:0,
                                                        self.placeholderView.frame.origin.y,
                                                        [[UIScreen mainScreen] bounds].size.height - (visible?leftPullPane.frame.size.width:0),
                                                        self.placeholderView.frame.size.height);
            }
            
        }];
    }
    //Just configure the size of the preview controller
    else if(pane==leftPullPane && UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation])){
        self.placeholderView.frame = CGRectMake(visible?leftPullPane.frame.size.width:0,
                                                self.placeholderView.frame.origin.y,
                                                [[UIScreen mainScreen] bounds].size.height - (visible?leftPullPane.frame.size.width:0),
                                                self.placeholderView.frame.size.height);
        
        
    }
    
    if(pane==leftPullPane) _leftPaneVisible = visible;
    else _rightPaneVisible = visible;
    
}

-(void)_moveView:(UIView*) view horizontallyBy:(float) amount{
    
    NSInteger x = [self _xCoordinateForView:view isVisible:(view == rightPullTab || view == rightPullPane) ? _rightPaneVisible : _leftPaneVisible] + amount;
    
    NSInteger limit1 = [self _xCoordinateForView:view isVisible:NO];
    NSInteger limit2 = [self _xCoordinateForView:view isVisible:YES];
    
    x = MIN(x,MAX(limit1,limit2));
    x = MAX(x,MIN(limit1,limit2));
    
    view.frame = CGRectMake(x,
                            view.frame.origin.y,
                            view.frame.size.width,
                            view.frame.size.height);
    
}

-(NSInteger) _xCoordinateForView:(UIView*) view isVisible:(BOOL) visible{
    if(view == leftPullPane) return (visible-1) * leftPullPane.frame.size.width;
    else if(view == leftPullTab) return visible * leftPullPane.frame.size.width;
    else{
        NSInteger width;
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        if(UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation])){
            width = (int) screenRect.size.height;
        }
        else{
            width = (int) screenRect.size.width;
        }
        if(view == rightPullPane) return width - visible * rightPullPane.frame.size.width;
        else return width - visible * rightPullPane.frame.size.width - rightPullTab.frame.size.width;
    }
    
}

#pragma mark - ZPQLPreviewControllerViewControllerDataSource


- (NSInteger) startIndex{
    return 0;
}

- (NSInteger) numberOfPreviewItemsInPreviewController: (ZPQLPreviewControllerViewController *) controller
{
    return 1;
}


- (id <QLPreviewItem>) previewController: (ZPQLPreviewControllerViewController *) controller previewItemAtIndex: (NSInteger) index{
    return [_attachments objectAtIndex:[_previewControllers indexOfObject:controller]];
}

#pragma mark - UITableViewDataSource

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView{
    
    //Standalone attachments have 2 sections, normal attachments 4
    ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) [_attachments objectAtIndex:_activeAttachmentIndex];
    BOOL isStandaloneAttachment = [attachment.parentKey isEqualToString:attachment.key];
    
    if(isStandaloneAttachment) return 2;
    else return 4;
}

-(NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) [_attachments objectAtIndex:_activeAttachmentIndex];
    BOOL isStandaloneAttachment = [attachment.parentKey isEqualToString:attachment.key];
    
    if(isStandaloneAttachment){
        if(section == 0) return @"Attachment tags";
        else return @"Attachment note";
    }
    else{
        if(section == 0) return @"Parent item tags";
        else if(section == 1) return @"Attachment tags";
        else if(section == 2) return @"Parent item notes";
        else return @"Attachment note";
    }
}


-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if(section == 2){
        ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) [_attachments objectAtIndex:_activeAttachmentIndex];
        ZPZoteroItem* parent = [ZPZoteroItem itemWithKey:attachment.parentKey];
        return [parent.notes count]+1;
    }
    else return 1;
}

// Custom height for the tag views

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    if(indexPath.section <=1){
        ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) [_attachments objectAtIndex:_activeAttachmentIndex];

        NSArray* tagButtons;
        
        //Standalone items

        if([attachment.key isEqualToString:attachment.parentKey]){
            if(indexPath.section == 0){
                tagButtons = _tagButtonsForAttachment;
            }
        }
        else{
            if(indexPath.section == 0){
                tagButtons = _tagButtonsForParent;
            }
            else{
                tagButtons = _tagButtonsForAttachment;
            }
            
        }
        
        if(tagButtons == NULL) return tableView.rowHeight;
        else{
            //Get the size based on content
            NSInteger y=0;
            for(UIView* subView in tagButtons){
                y=MAX(y,subView.frame.origin.y+subView.frame.size.height);
            }
            
            return MAX(y+7, tableView.rowHeight);
        }
    }
    else{
        return tableView.rowHeight;
    }
}


-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{

    DDLogVerbose(@"%@",indexPath);
    
    UITableViewCell *cell;
    NSString* CellIdentifier;
    
    ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) [_attachments objectAtIndex:_activeAttachmentIndex];
    ZPZoteroItem* parent;
    
    BOOL isStandaloneAttachment = [attachment.parentKey isEqualToString:attachment.key];
    
    ZPZoteroDataObject* tagSource = NULL;
    
    if(isStandaloneAttachment){
        if(indexPath.section == 0) tagSource = attachment;
    }
    else{
        if(indexPath.section == 0){
            parent = [ZPZoteroItem itemWithKey:attachment.parentKey];
            tagSource = parent;
        }
        else if(indexPath.section == 1) tagSource = attachment;
    }
    
    if(tagSource != NULL){
        if([tagSource.tags count]==0){
            CellIdentifier = @"NoTagsCell";
        }
        else{
            CellIdentifier = @"TagsCell";
        }
    }
    else{
        //Attachment note
        if(isStandaloneAttachment || indexPath.section==3) CellIdentifier = @"NoteCell";
        else{
            parent = [ZPZoteroItem itemWithKey:attachment.parentKey];
            if(indexPath.row == [parent.notes count]) CellIdentifier = @"NewNoteCell";
            else CellIdentifier = @"NoteCell";
        }
    }

    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }

    if([CellIdentifier isEqualToString:@"TagsCell"]){

        //Clean the cell
        for(UIView* view in cell.contentView.subviews ){
            [view removeFromSuperview];
        }

        if(tagSource == attachment){
            if(_tagButtonsForAttachment != NULL){
                for(UIView* tagButton in _tagButtonsForAttachment){
                    [cell.contentView addSubview:tagButton];
                }
            }
        }
        else{
            if(_tagButtonsForParent != NULL){
                for(UIView* tagButton in _tagButtonsForParent){
                    [cell.contentView addSubview:tagButton];
                }
            }
        }
        
    }
    else if([CellIdentifier isEqualToString:@"NoteCell"]){
        UILabel* noteText = (UILabel*) [cell viewWithTag:1];
        NSString* note;
        
        if(isStandaloneAttachment || indexPath.section==3){
            note = attachment.note;
        }
        else{
            note = [(ZPZoteroNote*)[parent.notes objectAtIndex:indexPath.row] note];
        }
        noteText.text = [[note stripHtml] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    }

    return  cell;
}

#pragma mark - UITableViewDelegate

// Populate the tags cells after they are displayed

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    
    if(indexPath.section<=1){
        
        ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) [_attachments objectAtIndex:_activeAttachmentIndex];
        BOOL isStandaloneAttachment = [attachment.parentKey isEqualToString:attachment.key];
        ZPZoteroDataObject* tagSource;
        
        if(isStandaloneAttachment){
            if(indexPath.section == 0){
                tagSource = attachment;
            }
        }
        else{
            if(indexPath.section == 0){
                ZPZoteroItem* parent = [ZPZoteroItem itemWithKey:attachment.parentKey];
                tagSource = parent;
            }
            else if(indexPath.section == 1){
                tagSource = attachment;
            }
        }
        
        if(tagSource != NULL && [tagSource.tags count]>0){
            
            if((tagSource == attachment && _tagButtonsForAttachment == NULL) ||
               (tagSource != attachment && _tagButtonsForParent == NULL)){
                [ZPTagController addTagButtonsToView:cell.contentView tags:tagSource.tags];
                
                if(tagSource == attachment) _tagButtonsForAttachment = cell.contentView.subviews;
                else _tagButtonsForParent = cell.contentView.subviews;
                
                [tableView reloadData];
                
                // This is more efficient, but produces an unnecessary animation
                
                    //[tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
            }
        }
    }
}
- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) [_attachments objectAtIndex:_activeAttachmentIndex];
    BOOL isStandaloneAttachment = [attachment.parentKey isEqualToString:attachment.key];

    //Parent tags
    if(indexPath.section == 0 && ! isStandaloneAttachment){
        ZPTagEditingViewController* tagController = [ZPTagEditingViewController instance];
        tagController.targetViewController = self;
        tagController.itemKey = attachment.parentKey;
        [self presentModalViewController:tagController animated:YES];
    }
    //Attachment tags
    else if((indexPath.section == 0 && isStandaloneAttachment)||
            (indexPath.section == 1 && ! isStandaloneAttachment)){

        ZPTagEditingViewController* tagController = [ZPTagEditingViewController instance];
        tagController.targetViewController = self;
        tagController.itemKey = attachment.itemKey;
        [self presentModalViewController:tagController animated:YES];

    }
    //Parent notes
    else if(indexPath.section == 2){
        ZPNoteEditingViewController* noteController = [ZPNoteEditingViewController instance];
        noteController.targetViewController = self;
        ZPZoteroItem* parent = [ZPZoteroItem itemWithKey:attachment.parentKey];
        if([parent.notes count]>indexPath.row){
            noteController.note = [parent.notes objectAtIndex:indexPath.row];
            noteController.isNewNote = FALSE;
        }
        else{
            ZPZoteroNote* note = [ZPZoteroNote noteWithKey:[ZPUtils randomString]];
            note.parentKey = parent.itemKey;
            noteController.note = note;
            noteController.isNewNote = TRUE;
        }
        [self presentModalViewController:noteController animated:YES];

    }
    //Attachment note
    else if(indexPath.section == 3 ||
            (indexPath.section == 1 && isStandaloneAttachment)){

        ZPNoteEditingViewController* noteController = [ZPNoteEditingViewController instance];
        noteController.note = attachment;
        noteController.isNewNote = FALSE;
        noteController.targetViewController = self;
        [self presentModalViewController:noteController animated:YES];

    }
    [aTableView deselectRowAtIndexPath:indexPath animated:NO];

}

#pragma mark - ZPNoteDisplay and ZPTagDisplay

-(void) refreshNotesAfterEditingNote:(ZPZoteroDataObject *)item{
    
    ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) [_attachments objectAtIndex:_activeAttachmentIndex];
    BOOL isStandaloneAttachment = [attachment.parentKey isEqualToString:attachment.key];
    
    NSInteger section;
    if(isStandaloneAttachment){
        section = 1;
    }
    else{
        if(item == attachment) section = 3;
        else section = 2;
    }

    [self.notesAndTagsTable reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationAutomatic];
}

-(void) refreshTagsFor:(NSString *)itemKey{

    ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) [_attachments objectAtIndex:_activeAttachmentIndex];
    BOOL isStandaloneAttachment = [attachment.parentKey isEqualToString:attachment.key];
    
    NSInteger section;
    if(isStandaloneAttachment){
        _tagButtonsForAttachment = NULL;
        section = 0;
    }
    else{
        if(itemKey == attachment.key){
            section = 1;
            _tagButtonsForAttachment = NULL;
        }
        else{
            section = 0;
            _tagButtonsForParent = NULL;
        }
    }

    [self.notesAndTagsTable reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationAutomatic];
}

@end
