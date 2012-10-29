//
//  ZPFileViewerViewController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 10/27/12.
//
//

#import <UIKit/UIKit.h>
#import "ZPAttachmentFileInteractionController.h"
#import "ZPCore.h"

@interface ZPFileViewerViewController : UIViewController{
    ZPAttachmentFileInteractionController* _attachmentInteractionController;
    NSMutableArray* _attachments;
    NSInteger _activeAttachmentIndex;
    BOOL _leftPaneVisible;
    BOOL _rightPaneVisible;
}

@property (retain, nonatomic) IBOutlet UINavigationBar* navigationBar;
@property (retain, nonatomic) IBOutlet UIView* leftPullTab;
@property (retain, nonatomic) IBOutlet UIView* leftPullPane;
@property (retain, nonatomic) IBOutlet UIView* rightPullTab;
@property (retain, nonatomic) IBOutlet UIView* rightPullPane;

- (IBAction) dismiss:(id)sender;
- (IBAction) actionButtonPressed:(id)sender;
- (IBAction) toggleStar:(id)sender;
- (IBAction) next:(id)sender;
- (IBAction) previous:(id)sender;
- (IBAction) presentAllFiles:(id)sender;

// Hiding and showing the pull panes
-(IBAction)togglePullPane:(id)sender;
-(IBAction)handlePanGestureOnPullPane:(UIPanGestureRecognizer *)gestureRecognizer;

-(void) addAttachment:(ZPZoteroAttachment*)attachment;

@end
