//
//  ZPModalViewController.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 6/21/13.
//
//

#import "ZPModalViewController.h"

@interface ZPModalViewController ()
+ (UIViewController*) _topMostController;
@end


@implementation ZPModalViewController

static NSMutableDictionary* _instanceStore;

+(void) initialize{
    _instanceStore = [[NSMutableDictionary alloc] init];
}

+(ZPModalViewController*) instance{

    NSString* className = NSStringFromClass([self class]);
    ZPModalViewController* instance = [_instanceStore objectForKey:className];
    
    //If we do not have an instance or an instance is already being presented,
    //create a new instance
    
    if(instance == nil || [instance parentViewController]){
        //Remove the ZP class name prefix
        NSString* storyboardIdentifier = [className substringFromIndex:2];
        instance =[[UIApplication sharedApplication].delegate.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:storyboardIdentifier];
        [_instanceStore setObject:instance forKey:className];
    }
    return instance;

}
-(void) presentModally:(BOOL) animated{

    UIViewController* topController = [ZPModalViewController _topMostController];
    
    // If the top controller is in the process of being presented or dismissed,
    // wait 100ms and then try presenting again
    
    if([topController isBeingPresented] || [topController isBeingDismissed]){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
            [self presentModally:animated];
        });
    }
    
    // All clear to present immediately
    
    else{
        [topController presentModalViewController:self animated:animated];
    }
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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

+ (UIViewController*) _topMostController
{
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    return topController;
}

@end
