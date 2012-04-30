//
//  ZPFileChannel_LocalNetworkShare.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPFileChannel_Samba.h"
#import "tangoConnection.h"
#import "tangoFileInfo.h"
#import "ZPPreferences.h"
#import "ZPServerConnection.h"
#import "KeychainItemWrapper.h"
#import "ZPLogger.h"
#import "ZPDownloadAuthenticationDialogViewController.h"
#import "ZPSambaServerPickerDialog.h"

@interface ZPFileChannel_Samba (){
    BOOL _shouldTimeout;
    NSMutableArray* _servers;
    NSMutableArray* _waitQueue;
    ZPZoteroAttachment* _currentAttachement;
    NSString* _hostname;
    NSString* _username;
    NSString* _password;
    NSNetServiceBrowser* _domainBrowser;

}

-(void) _timeoutSearch;
-(void) _displayServerNotFoundError;
-(void) _displayServerChoiceDialog;
-(void) _dismissServerChoiceDialog;
-(BOOL) _serverOnline;
-(void) _clearCurrentAndProcessQaitQueue;

-(void) _downloadAttachment:(ZPZoteroAttachment*)attachment;


//Ask the user to pick a server and to enter credentials
-(void) _configureHostname;
-(void) _configureUsernameAndPassword;

//Methods for accessing key chain
-(void) _readUsernameAndPasswordFromKeychain;
-(void) _writeUsernameAndPasswordToKeychain;

@end

@implementation ZPFileChannel_Samba 

@synthesize hostname = _hostname, knownServers = _servers;

-(id) init{
    self=[super init];
    _servers = [[NSMutableArray alloc] init];
    _waitQueue = [[NSMutableArray alloc] init]; 
    return self;
}

-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    @synchronized(self){
        
        //Only allow processing one attachment at a time
        if(_currentAttachement != NULL && [[ZPPreferences instance] useSamba]){
            [_waitQueue addObject:attachment];
            
            NSLog(@"Adding to wait queue %@",attachment.key);

        }
        else if([[ZPPreferences instance] useSamba]){

            NSLog(@"Using Samba %@",attachment.key);
            
            _currentAttachement = attachment;

            if(! [self _serverOnline]) [self performSelectorOnMainThread:@selector(_configureHostname) withObject:NULL waitUntilDone:NO];
            else{
                if(_username == NULL || _password == NULL) [self _readUsernameAndPasswordFromKeychain];
                
                if(_username == NULL || _password == NULL) [self performSelectorOnMainThread:@selector(_configureUsernameAndPassword) withObject:NULL waitUntilDone:NO];
                //Attempt connecting and downloading
                else [self _downloadAttachment:attachment]; 
            }
        }  
        // If Samba is not in use, just notify that we are done
        else [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:NULL usingFileChannel:self];
    }        
    
}

-(void) _configureHostname{
    NSLog(@"Configuring samba host");
    
    @synchronized(self){
        [_servers removeAllObjects];    
    }
    
    if(_domainBrowser == NULL){
        _domainBrowser = [[NSNetServiceBrowser alloc] init];
        _domainBrowser.delegate = self;
    }
    else {
        [_domainBrowser stop];
    }
    
    [_domainBrowser searchForServicesOfType:@"_smb._tcp."
                                       inDomain:@"local."];
    
    //Timeout in 5 seconds
    _shouldTimeout = TRUE;
    [self performSelector:@selector(_timeoutSearch) withObject:NULL afterDelay:5];

}

-(void) _configureUsernameAndPassword{
    NSLog(@"Configuring username and password");
    
    UIViewController* root = [UIApplication sharedApplication].delegate.window.rootViewController;

    UIStoryboard *storyboard = root.storyboard;
    ZPDownloadAuthenticationDialogViewController* controller = [storyboard instantiateViewControllerWithIdentifier:@"AuthenticateToServer"];
    
    [controller setHostname:_hostname];
    [controller setCaller:self];
    
    [root presentModalViewController:controller animated:YES];
}

-(void) setUsername:(NSString *)username andPassword:(NSString *)password{
    [super setUsername:username andPassword:password];
    
    //If the username is not null, write it to keychain and proceed with downloading
    if(username!= NULL){
        [self _writeUsernameAndPasswordToKeychain];
        [self _downloadAttachment:_currentAttachement];
    }
    else{
        [[ZPServerConnection instance] finishedDownloadingAttachment:_currentAttachement toFileAtPath:NULL usingFileChannel:self];
        [self cancelCurrent];
    }
}
-(void) _readUsernameAndPasswordFromKeychain{
    NSLog(@"Reading samba credentials from keychain");

    KeychainItemWrapper *keychain = 
    [[KeychainItemWrapper alloc] initWithIdentifier:@"ZotPadSamba" accessGroup:nil];
    
    // Get username from keychain (if it exists)
    //TODO: Is using __bridge correct here
    _username = [keychain objectForKey:(__bridge id)kSecAttrAccount];
    _password = [keychain objectForKey:(__bridge id)kSecValueData];

}
-(void) _writeUsernameAndPasswordToKeychain{
    NSLog(@"Writing samba credentials to keychain");

    KeychainItemWrapper *keychain = 
    [[KeychainItemWrapper alloc] initWithIdentifier:@"ZotPadSamba" accessGroup:nil];
    
    [keychain setObject:_username forKey:(__bridge id)kSecAttrAccount];
    [keychain setObject:_password forKey:(__bridge id)kSecValueData];   
    
}

-(void) _downloadAttachment:(ZPZoteroAttachment*)attachment{

    
    NSString* share = [NSString stringWithFormat:@"\\\\%@\\%@",_hostname,[[ZPPreferences instance] sambaShareName]];

    NSLog(@"Creating connection");
    
    tango_connection_t *connection = tango_create([share cString], [_username cString], [_password cString]);
    
    NSLog(@"Connecting");
    NSInteger errorCode = tango_connect(connection);
    if(errorCode <= 0){
        if(errorCode==-1){
            NSLog(@"Failed to connect");
        }
        else {
            NSLog(@"Tango error %i, message: %@",connection->error,[NSString stringWithCString:connection->error_message]);
        }
        
    }
    NSLog(@"Reading content of folder");

    tango_file_info_t directory;
    strcpy(directory.filename,[attachment.key cString]);
    strcpy(directory.path, "");
    directory.is_folder = 1;
    directory.file_size = 0;

    tango_file_info_t file_info_arr[256];
	int file_count = tango_list_directory(connection, &directory, file_info_arr, 256);

    NSLog(@"Found %i files");
    
    NSLog(@"Done");
    tango_close(connection);
    tango_release(connection);

    
}


-(void) _timeoutSearch{
    if(_shouldTimeout){
        NSLog(@"Samba search timed out");
        [_domainBrowser stop];
        [self _displayServerNotFoundError];
    }
}

- (void) _displayServerNotFoundError{
    [_domainBrowser stop];
    
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Server not found"
                                                      message:@"Servers with shared folders were not found in the local network."
                                                     delegate:self
                                            cancelButtonTitle:@"Cancel"
                                            otherButtonTitles:@"Disable SMB",nil];
    
    [message show];
}
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    //Disable Samba
    if(buttonIndex == 1){
        [[ZPPreferences instance] setUseSamba:FALSE];
    }
}

-(void) _displayServerChoiceDialog{
    @synchronized(self){
        [_servers sortUsingSelector:@selector(compare:)];
    }
    UIViewController* root = [[[[[UIApplication sharedApplication] keyWindow] subviews] objectAtIndex:0] nextResponder];

    UIStoryboard *storyboard = root.storyboard;
    ZPSambaServerPickerDialog* controller = [storyboard instantiateViewControllerWithIdentifier:@"ChooseSambaServer"];
   
    [controller setCaller:self];
    
    [root presentModalViewController:controller animated:YES];

}


-(void) _clearCurrentAndProcessQaitQueue{

    @synchronized(self){
        NSLog(@"Clearing current and processing wait queue");
        _currentAttachement = NULL;
        ZPZoteroAttachment* attachment;
        for(attachment in _waitQueue){
            [self performSelectorInBackground:@selector(startDownloadingAttachment:) withObject:attachment];
        }
        [_waitQueue removeAllObjects];
    }
    
}


-(void) dialogDismissed{
    if(_currentAttachement != NULL)  [self startDownloadingAttachment:_currentAttachement];
    [self _clearCurrentAndProcessQaitQueue];
}

#pragma mark - Button actions

-(void)disableSamba{
    [[ZPPreferences instance] setUseSamba:FALSE];
    [self cancelCurrent];
}
-(void)cancelCurrent{
    [[ZPServerConnection instance] finishedDownloadingAttachment:_currentAttachement toFileAtPath:NULL usingFileChannel:self];
    _currentAttachement = NULL;
}

# pragma mark - Methods overriding super class
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{

}

-(void) useProgressView:(UIProgressView*) progressView forAttachment:(ZPZoteroAttachment*)attachment{
    
}

#pragma mark - NSNetServiceBrowserDelegate methods

// Sent when browsing begins
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser
{
    NSLog(@"Bonjour started");
}

// Sent when browsing stops
- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser
{
    NSLog(@"Bonjour stopped");
}

// Sent if browsing fails
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
             didNotSearch:(NSDictionary *)errorDict
{
    NSLog(@"Bonjour Error %@",[errorDict objectForKey:NSNetServicesErrorCode]);
}

// Sent when a service appears
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
           didFindService:(NSNetService *)aNetService
               moreComing:(BOOL)moreComing
{
    //We are receiving something, so no need to timeout
    
    _shouldTimeout = FALSE;
    NSLog(@"Bonjour discovered service %@",[aNetService debugDescription]);
    NSString* name = aNetService.name;
    @synchronized(self){
        [_servers addObject:name];
    }
    
    if(! moreComing){
        [self _displayServerChoiceDialog];
    }
}

// Sent when a service disappears
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
         didRemoveService:(NSNetService *)aNetService
               moreComing:(BOOL)moreComing
{
    NSLog(@"Bonjour service disappeared %@",[aNetService debugDescription]);
    //Clear hostname if the host disappears
    @synchronized(self){
        [_servers removeObject:aNetService.name];
    }
}

- (BOOL) _serverOnline{
    if(_hostname==NULL){
        return NO;   
    }
    else{
        @synchronized(self){
            return [_servers indexOfObject:_hostname] != NSNotFound;
        }
        
    }
}

@end
     
     

