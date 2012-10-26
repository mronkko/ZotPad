//
//  ZPCollectionsAndTagsViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 9/6/12.
//
//

#import <UIKit/UIKit.h>
#import "HLSPlaceholderViewController.h"
#import "ZPBarBackgroundGradientView.h"

@interface ZPCollectionsAndTagsViewController : HLSPlaceholderViewController <UIGestureRecognizerDelegate>

@property (retain) IBOutlet UIView* collectionsView;
@property (retain) IBOutlet ZPBarBackgroundGradientView* tagsHeader;
@property (retain) IBOutlet UIView* tagsView;
@property (retain) IBOutlet UIImageView* headerArrowLeft;
@property (retain) IBOutlet UIImageView* headerArrowRight;
@property (retain) IBOutlet UIBarButtonItem* gearButton;
@property (retain) IBOutlet UIBarButtonItem* cacheControllerPlaceHolder;

//Toolbar, iPhone only
@property (retain) IBOutlet UIToolbar* toolBar;

-(IBAction)toggleTagSelector:(id)sender;
-(IBAction)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer;

@end
