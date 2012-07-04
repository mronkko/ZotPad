//
//  ZPFileChannel_LocalNetworkShare.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Mikko Rönkkö. All rights reserved.
//

#import "ZPFileChannel.h"


@interface ZPFileChannel_Samba : ZPFileChannel <NSNetServiceBrowserDelegate, UIAlertViewDelegate>{
}

@property (retain) NSString* hostname;
@property (retain) NSArray* knownServers;

-(void)disableSamba;
-(void)cancelCurrent;
-(void)dialogDismissed;

@end
