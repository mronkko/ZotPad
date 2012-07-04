//
//  ZPSambaServerPickerDialog.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 29.4.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZPFileChannel_Samba.h"
@interface ZPSambaServerPickerDialog : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (retain) ZPFileChannel_Samba* caller;

-(IBAction)disableSamba:(id)sender;
-(IBAction)cancelSamba:(id)sender;

@end
