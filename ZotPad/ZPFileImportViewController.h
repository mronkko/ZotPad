//
//  ZPFileImportView.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 8.4.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ZPFileImportViewController : UIViewController <UIAlertViewDelegate>{
    NSInteger _status;
}

@property (retain) NSURL* url;

@end
