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
#import "KeychainItemWrapper.h"

@implementation ZPFileChannel_Samba 
    
-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    if([[ZPPreferences instance] useSamba]){
        if(_password == NULL || _username == NULL){
            //Get the username from keychain
            
            KeychainItemWrapper *keychain = 
            [[KeychainItemWrapper alloc] initWithIdentifier:@"ZotPadSamba" accessGroup:nil];

            // Get username from keychain (if it exists)
            //TODO: Is __bridge correct here
            _username = [keychain objectForKey:(__bridge id)kSecAttrAccount];
            _username = [keychain objectForKey:(__bridge id)kSecValueData];
            
        }

        tangoConnection *connection = [[tangoConnection alloc] initWithUsername:_username 
                                                                       password:_password
                                                                          share:[[ZPPreferences instance] sambaURL]];
        
        if([connection connect]){
            
        }
        else{
            NSLog(@"Samba connection failed with error: %@",[connection errorMessage]);
        }
/*                                                      
        KeychainItemWrapper *keychain = 
        [[KeychainItemWrapper alloc] initWithIdentifier:@"ZotPadSamba" accessGroup:nil];

        [keychain setObject:_username forKey:(__bridge id)kSecAttrAccount];
        [keychain setObject:_password forKey:(__bridge id)kSecValueData];   
*/        
    }
    // If Samba is not in use, just notify that we are done
    else [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:NULL usingFileChannel:self];

}

-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{

}

-(void) useProgressView:(UIProgressView*) progressView forAttachment:(ZPZoteroAttachment*)attachment{
    
}

@end
