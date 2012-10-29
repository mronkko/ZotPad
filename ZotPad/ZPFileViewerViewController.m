//
//  ZPFileViewerViewController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 10/27/12.
//
//

#import "ZPFileViewerViewController.h"

#import "ZPStarBarButtonItem.h"
#import <QuartzCore/QuartzCore.h>

//Unzipping and base64 decoding
#import "ZipArchive.h"
#import "NSString+Base64.h"

@interface ZPFileViewerViewController ()

-(void)_togglePullPane:(UIView*)pane duration:(float) duration toVisible:(BOOL)visible;
-(void)_moveView:(UIView*) view horizontallyBy:(float) amount;
-(NSInteger) _xCoordinateForView:(UIView*) view isVisible:(BOOL) visible;

@end

@implementation ZPFileViewerViewController

@synthesize navigationBar, leftPullPane, leftPullTab, rightPullPane, rightPullTab;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _attachments = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    // Set up buttons
    
    UIBarButtonItem* doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                target:self
                                                                                action:@selector(dismiss:)];
    
    UISegmentedControl* segmentControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:[UIImage imageNamed:@"left"],[UIImage imageNamed:@"right"], nil]];
    segmentControl.segmentedControlStyle = UISegmentedControlStyleBar;
    
    UIBarButtonItem* forwardAndBackButtons = [[UIBarButtonItem alloc] initWithCustomView:segmentControl];
    
    UIBarButtonItem* presentAllFilesButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"more"]
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(presentAllFiles:)];

    UIBarButtonItem* spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    spacer.width = 20;
    
    
    
    self.navigationItem.leftBarButtonItems = [NSArray arrayWithObjects:doneButton, spacer, forwardAndBackButtons,presentAllFilesButton, nil];
    
    UIBarButtonItem* starButton = [[ZPStarBarButtonItem alloc] init];
    
    UIBarButtonItem* actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionButtonPressed:)];
    
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:actionButton, starButton, nil];
    self.navigationItem.title = @"File viewer";
    
    [self.navigationBar pushNavigationItem:self.navigationItem animated:NO];
    
}

-(void) viewWillAppear:(BOOL)animated{
    //Configure the pull panes
    
    for(NSInteger index =0; index <2;++index){
        
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
    
    //Hide both pull tabs

    rightPullPane.frame = CGRectMake(rightPullPane.frame.origin.x + rightPullPane.frame.size.width,
                                    rightPullPane.frame.origin.y,
                                    rightPullPane.frame.size.width,
                                    rightPullPane.frame.size.height);

    rightPullTab.frame = CGRectMake(rightPullTab.frame.origin.x + rightPullPane.frame.size.width,
                                    rightPullTab.frame.origin.y,
                                    rightPullTab.frame.size.width,
                                    rightPullTab.frame.size.height);


    leftPullPane.frame = CGRectMake(leftPullPane.frame.origin.x - leftPullPane.frame.size.width,
                                    leftPullPane.frame.origin.y,
                                    leftPullPane.frame.size.width,
                                    leftPullPane.frame.size.height);

    leftPullTab.frame = CGRectMake(leftPullTab.frame.origin.x - leftPullPane.frame.size.width,
                                   leftPullTab.frame.origin.y,
                                   leftPullTab.frame.size.width,
                                   leftPullTab.frame.size.height);
    
    // Add gesture recognizers to pull tabs

}


- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {

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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Managing the displayed items

- (void) addAttachment:(ZPZoteroAttachment *)attachment{
    
    //Do not add the object if it already exists
    if([_attachments containsObject:attachment]){
        if([_attachments lastObject]!=attachment){
            [_attachments removeObject:attachment];
            [_attachments addObject:attachment];
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
    }
    _activeAttachmentIndex = [_attachments count]-1;
}

#pragma mark - Button actions

-(IBAction) dismiss:(id)source{
    [self dismissModalViewControllerAnimated:YES];
}

- (IBAction) actionButtonPressed:(id)sender{
    
    ZPZoteroAttachment* currentAttachment = [_attachments objectAtIndex:_activeAttachmentIndex];
    if(_attachmentInteractionController == NULL)  _attachmentInteractionController = [[ZPAttachmentFileInteractionController alloc] init];
    [_attachmentInteractionController setAttachment:currentAttachment];
    
    [_attachmentInteractionController presentOptionsMenuFromBarButtonItem:sender];
}


- (IBAction) next:(id)sender{
    
}

- (IBAction) previous:(id)sender{
    
}

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

        }];
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


@end
