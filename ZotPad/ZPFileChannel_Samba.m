//
//  ZPFileChannel_LocalNetworkShare.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPFileChannel_Samba.h"
#import "tangoConnection.h"
#import "ZPPreferences.h"
#import "ZPServerConnection.h"

@implementation ZPFileChannel_Samba 
    
-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    if([[ZPPreferences instance] useSamba]){
        if(_password == NULL){
            
        }
    }
    // If Samba is not in use, just notify that we are done
    else [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:NULL usingFileChannel:self];

}

-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{

}

-(void) useProgressView:(UIProgressView*) progressView forAttachment:(ZPZoteroAttachment*)attachment{
    
}

@end
