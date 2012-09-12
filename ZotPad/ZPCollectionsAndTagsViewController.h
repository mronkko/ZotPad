//
//  ZPCollectionsAndTagsViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 9/6/12.
//
//

#import <UIKit/UIKit.h>
#import "HLSPlaceholderViewController.h"

@interface ZPCollectionsAndTagsViewController : HLSPlaceholderViewController <UIGestureRecognizerDelegate>

@property (retain) IBOutlet UIView* collectionsView;
@property (retain) IBOutlet UIView* tagsHeader;
@property (retain) IBOutlet UIView* tagsView;
@property (retain) IBOutlet UIImageView* headerArrowLeft;
@property (retain) IBOutlet UIImageView* headerArrowRight;
@property (retain) IBOutlet UIBarButtonItem* gearButton;
@property (retain) IBOutlet UIBarButtonItem* cacheControllerPlaceHolder;

-(IBAction)toggleTagSelector:(id)sender;
-(IBAction)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer;

@end
