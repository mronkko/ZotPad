//
//  ZPServerConnection.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

//TODO: Implement webdav client http://code.google.com/p/wtclient/


#import "ZPAppDelegate.h"
#import "ZPServerConnection.h"
#import "ZPAuthenticationDialog.h"
#import "ZPServerResponseXMLParser.h"
#import "ZPServerResponseXMLParserItem.h"
#import "ZPServerResponseXMLParserLibrary.h"
#import "ZPServerResponseXMLParserCollection.h"
#import "ZPAuthenticationProcess.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroLibrary.h"
#import "ZPZoteroNote.h"
#import "ZPZoteroAttachment.h"
#import "ZPDataLayer.h"

#import "ASIHTTPRequest.h"

//Private methods

@interface ZPServerConnection();
    

-(ZPServerResponseXMLParser*) makeServerRequest:(NSInteger)type withParameters:(NSDictionary*) parameters;

@end


@implementation ZPServerConnection

static ZPServerConnection* _instance = nil;

const NSInteger ZPServerConnectionRequestGroups = 1;
const NSInteger ZPServerConnectionRequestCollections = 2;
const NSInteger ZPServerConnectionRequestSingleCollection = 3;
const NSInteger ZPServerConnectionRequestItems = 4;
const NSInteger ZPServerConnectionRequestItemsAndChildren = 5;
const NSInteger ZPServerConnectionRequestSingleItem = 6;
const NSInteger ZPServerConnectionRequestSingleItemChildren = 7;

-(id)init
{
    self = [super init];
        
    _activeRequestCount = 0;
    _debugServerConnection = TRUE;
    _attachmentFileDataObjectsByConnection = [NSMutableDictionary dictionary];
    _attachmentObjectsByConnection = [NSMutableDictionary dictionary];

    return self;
}

/*

 Singleton accessor
 */

+(ZPServerConnection*) instance {
    if(_instance == NULL){
        _instance = [[ZPServerConnection alloc] init];
    }
    return _instance;
}

/*
 We assume that the client is authenticated if a oauth key exists. The key will be cleared if we notice that it is not valid while using it.
 */

- (BOOL) authenticated{
    
    return([[NSUserDefaults standardUserDefaults] objectForKey:@""] != nil);
    
}

-(NSData*) _retrieveDataFromServer:(NSString*)urlString{
    _activeRequestCount++;
    
    if(_debugServerConnection){
        NSLog(@"Request started: %@ Active queries: %i",urlString,_activeRequestCount);
    }
    
    
    //First request starts the network indicator
    if(_activeRequestCount==1) [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    NSURLRequest * urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    NSURLResponse * response = nil;
    NSError* error = nil;
    NSData* responseData= [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];

    //If we receive a 403 (forbidden) error, delete the authorization key because we know that it is
    //no longer valid.
    if([(NSHTTPURLResponse*)response statusCode]==403){
        NSLog(@"The authorization key is no longer valid.");
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"OAuthKey"];
    }
    
    _activeRequestCount--;
    
    //Last request hides the network indicator
    if(_activeRequestCount==0) [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

    return responseData;
}

/*

 This will get the localized item types
 https://api.zotero.org/itemTypes

 This will get the localized fields for item type
 https://api.zotero.org/itemFields?itemType=book
 
 This will get a list of valid creator types
 https://api.zotero.org/itemTypeCreatorTypes?itemType=book
 
 This will get a template for a new item
 https://api.zotero.org/items/new?itemType=book
 
*/


-(ZPServerResponseXMLParser*) makeServerRequest:(NSInteger)type withParameters:(NSDictionary*) parameters{
    
    
    NSData* responseData = NULL;
    NSString* urlString;
   
    NSString* oauthkey =  [[NSUserDefaults standardUserDefaults] objectForKey:@"OAuthKey"];
    if(oauthkey!=NULL){

        NSInteger libraryID = [(NSNumber*)[parameters objectForKey:@"libraryID"] integerValue];
        
        if(libraryID==1 || libraryID == 0){
            urlString = [NSString stringWithFormat:@"https://api.zotero.org/users/%@/",[[NSUserDefaults standardUserDefaults] objectForKey:@"userID"]];
        }
        else{
            urlString = [NSString stringWithFormat:@"https://api.zotero.org/groups/%i/",libraryID];        
        }
        
        
        if(type==ZPServerConnectionRequestGroups){
            urlString = [NSString stringWithFormat:@"%@groups?key=%@&content=none",urlString,oauthkey];
        }
        else if (type==ZPServerConnectionRequestCollections){
            urlString = [NSString stringWithFormat:@"%@collections?key=%@",urlString,oauthkey];
        }
        else if (type==ZPServerConnectionRequestSingleCollection){
            urlString = [NSString stringWithFormat:@"%@collections/%@?key=%@",urlString,[parameters objectForKey:@"collectionKey"],oauthkey];
        }

        else if (type==ZPServerConnectionRequestItems){
            NSString* collectionKey = [parameters objectForKey:@"collectionKey"];

            if(collectionKey!=NULL){
                urlString = [NSString stringWithFormat:@"%@collections/%@/items?key=%@&format=atom",urlString,collectionKey,oauthkey];
            }
            else{
                urlString = [NSString stringWithFormat:@"%@items/top?key=%@&format=atom",urlString,oauthkey];
            }
        }
        else if (type==ZPServerConnectionRequestItemsAndChildren){
            NSString* collectionKey = [parameters objectForKey:@"collectionKey"];
            NSAssert(collectionKey==NULL,@"Cannot request child items for collection");
            urlString = [NSString stringWithFormat:@"%@items?key=%@&format=atom",urlString,oauthkey];
        }

        else if( type == ZPServerConnectionRequestSingleItem){
             NSString* itemKey = [parameters objectForKey:@"itemKey"];

            urlString = [NSString stringWithFormat:@"%@items/%@?key=%@&format=atom",urlString,itemKey,oauthkey];
        }
        else if( type == ZPServerConnectionRequestSingleItemChildren){
            NSString* itemKey = [parameters objectForKey:@"itemKey"];
            
            urlString = [NSString stringWithFormat:@"%@items/%@/children?key=%@&format=atom",urlString,itemKey,oauthkey];
        }
                
        if(parameters!=NULL){
            for(id key in parameters){
                if(! [@"itemKey" isEqualToString: key] &&
                   ! [@"collectionKey" isEqualToString: key] &&
                   ! [@"libraryID" isEqualToString: key]) {
                    urlString = [NSString stringWithFormat:@"%@&%@=%@",urlString,key,[[parameters objectForKey:key] stringByAddingPercentEscapesUsingEncoding:
                                                                                      NSASCIIStringEncoding]];
                
                }
            }
        }
        
        responseData = [self _retrieveDataFromServer:urlString];
    }

    if(responseData!=NULL){
        NSXMLParser* parser = [[NSXMLParser alloc] initWithData:responseData];

        ZPServerResponseXMLParser* parserDelegate = NULL;
        //Choose the parser based on what we expect to receive
        
        if(type==ZPServerConnectionRequestGroups){
            parserDelegate =  [[ZPServerResponseXMLParserLibrary alloc] init];    
        }
        else if (type==ZPServerConnectionRequestCollections || type == ZPServerConnectionRequestSingleCollection){
            parserDelegate =  [[ZPServerResponseXMLParserCollection alloc] init];    
        }
        else if (type==ZPServerConnectionRequestItems || type == ZPServerConnectionRequestSingleItem || type== ZPServerConnectionRequestItemsAndChildren || type== ZPServerConnectionRequestSingleItemChildren){
            parserDelegate =  [[ZPServerResponseXMLParserItem alloc] init];    
        }
        
//       if(_debugServerConnection)  NSLog(@"%@",[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
    
        [parser setDelegate: parserDelegate];
        [parser parse];

        if(_debugServerConnection){
            //Iy is OK to get 1/0 here because queries that return a single results do not have totalResults
            NSLog(@"Request returned %i/%i results: %@ Active queries: %i",[[parserDelegate parsedElements] count],[parserDelegate totalResults], urlString,_activeRequestCount);            
            
            //If there are no results, dump the entire response so that we see what the problem was
            if([[parserDelegate parsedElements] count] == 0){
                NSLog(@"%@",[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
            }
        }


        return parserDelegate;
    }
    else{
        if(oauthkey==NULL){

            //Initialize a new authentication process if there is currently not an ongoing one
            if(![[ZPAuthenticationProcess instance] isActive]){
                [[ZPAuthenticationProcess instance] startAuthentication];
            }
        }
        return NULL;
    }
}

-(ZPZoteroItem*) retrieveSingleItemDetailsFromServer:(ZPZoteroItem*)item{

    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:item.libraryID forKey:@"libraryID"];
    [parameters setObject:item.key forKey:@"itemKey"];
    [parameters setObject:@"json" forKey:@"content"];
    
    ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestSingleItem withParameters:parameters];
    
    NSArray* parsedArray = [parserDelegate parsedElements];
    
    if(parserDelegate == NULL || [parsedArray count] == 0 ) return NULL;
    
    item = [parsedArray objectAtIndex:0];   

    //Request attachments for the single item

    if(item.numChildren >0){
        [parameters setObject:@"none" forKey:@"content"];
        parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestSingleItemChildren withParameters:parameters];
        
        NSMutableArray* attachments = NULL;
        NSMutableArray* notes = NULL;
        
        for(NSObject* child in [parserDelegate parsedElements] ){
            if([child isKindOfClass:[ZPZoteroAttachment class]]){
                if(attachments == NULL) attachments = [NSMutableArray array];
                
                //For now only add attachments that have download URLs on the Zotero server.
                if([(ZPZoteroAttachment*) child attachmentURL] != NULL) [attachments addObject:child];
            }
            else if([child isKindOfClass:[ZPZoteroNote class]]){
                if(notes == NULL) notes = [NSMutableArray array];
                [notes addObject:child];
            }
        }
        
        if(notes != NULL) item.notes = notes;
        else item.notes = [NSArray array];
        
        if(attachments != NULL) item.attachments = attachments;
        else item.attachments = [NSArray array];
    
    }
    return item;
}

-(NSArray*) retrieveLibrariesFromServer{
        
    //Retrieve all libraries from the server
    

    ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestGroups withParameters:NULL];

    NSArray* returnArray = [parserDelegate parsedElements];
 
    if(parserDelegate == NULL) return NULL;
    
    //If there is more data coming, retrieve it
    while([returnArray count] < parserDelegate.totalResults){

        NSMutableDictionary* parameters=[[NSMutableDictionary alloc] initWithCapacity:1];
        [parameters setObject:[NSString stringWithFormat:@"%i",[returnArray count]] forKey:@"start"];

        ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestGroups withParameters:parameters];

        if(parserDelegate == NULL) return NULL;
        
        NSArray* returnArray = [parserDelegate parsedElements];

        returnArray=[returnArray arrayByAddingObjectsFromArray:parserDelegate.parsedElements];
    }
    
    
    return returnArray;
    
}

-(NSArray*) retrieveCollectionsForLibraryFromServer:(NSNumber*)libraryID{
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:libraryID forKey:@"libraryID"];

    ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestCollections withParameters:parameters];
    if(parserDelegate == NULL) return NULL;

    NSArray* returnArray = [parserDelegate parsedElements];
    
    //If there is more data coming, retrieve it
    while([returnArray count] < parserDelegate.totalResults){
        
        [parameters setObject:[NSString stringWithFormat:@"%i",[returnArray count]] forKey:@"start"];
        
        ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestCollections withParameters:parameters];
        if(parserDelegate == NULL) return NULL;
        
        returnArray=[returnArray arrayByAddingObjectsFromArray:parserDelegate.parsedElements];
    }
        
    return returnArray;
}

-(ZPZoteroCollection*) retrieveCollection:(NSString*)collectionKey fromLibrary:(NSNumber*)libraryID{

    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:libraryID forKey:@"libraryID"];
    [parameters setValue:collectionKey forKey:@"collectionKey"];
    
    ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestSingleCollection withParameters:parameters];
    if(parserDelegate == NULL) return NULL;
    
    ZPZoteroCollection* collection= [[parserDelegate parsedElements] objectAtIndex:0];
    collection.libraryID = libraryID;
    
    return  collection;

}


/*

Retrieves items from server and stores these in the database. Returns and array of NSStrings that contain the item keys
   
*/

-(ZPServerResponseXMLParser*) retrieveItemsFromLibrary:(NSNumber*)libraryID collection:(NSString*)collectionKey searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortIsDescending limit:(NSInteger)limit start:(NSInteger)start getItemDetails:(BOOL)getItemDetails {
    
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:libraryID  forKey:@"libraryID"];

    if(collectionKey!=NULL) [parameters setObject:collectionKey forKey:@"collectionKey"];
    
    if(getItemDetails){
//        [parameters setObject:@"bib,json" forKey:@"content"];
        [parameters setObject:@"bib" forKey:@"content"];
        [parameters setObject:@"apa" forKey:@"style"];
    }
    else{
        [parameters setObject:@"none" forKey:@"content"];
    }
    
    //Search
    if(searchString!=NULL && ! [searchString isEqualToString:@""]){
        [parameters setObject:[searchString stringByAddingPercentEscapesUsingEncoding:
                               NSASCIIStringEncoding] forKey:@"q"];
    }
    //Sort
    if(orderField!=NULL){
        [parameters setObject:orderField forKey:@"order"];

        if(sortIsDescending){
            [parameters setObject:@"desc" forKey:@"sort"];
        }
        else{
            [parameters setObject:@"asc" forKey:@"sort"];
        }
    }
    //Get the most recent first by default
    else{
        [parameters setObject:@"dateModified" forKey:@"order"];
        [parameters setObject:@"desc" forKey:@"sort"];
    }

    if(start!=0){
        [parameters setObject:[NSString  stringWithFormat:@"%i",start] forKey:@"start"];
    }
    if(limit!=0){
        [parameters setObject:[NSString  stringWithFormat:@"%i",limit] forKey:@"limit"];
    }
    
    ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestItems withParameters:parameters];
    
    return parserDelegate;
    
}

-(ZPServerResponseXMLParser*) retrieveNotesAndAttachmentsFromLibrary:(NSNumber*)libraryID limit:(NSInteger)limit start:(NSInteger)start{
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithObject:libraryID  forKey:@"libraryID"];
    
    [parameters setObject:@"none" forKey:@"content"];
    //Get the most recent first by default
    [parameters setObject:@"dateModified" forKey:@"order"];
    [parameters setObject:@"desc" forKey:@"sort"];
    [parameters setObject:@"attachment || note" forKey:@"itemType"];
    
    if(start!=0){
        [parameters setObject:[NSString  stringWithFormat:@"%i",start] forKey:@"start"];
    }
    if(limit!=0){
        [parameters setObject:[NSString  stringWithFormat:@"%i",limit] forKey:@"limit"];
    }
    
    ZPServerResponseXMLParser* parserDelegate =  [self makeServerRequest:ZPServerConnectionRequestItemsAndChildren withParameters:parameters];
    
    return parserDelegate;
    
}

/*

 Methods for dowloading files
 
 */

-(void) downloadAttachment:(ZPZoteroAttachment*)attachment{
    
    //TODO: Notify the UI that  we are starting a download to show a progress indicator
    
    NSString* oauthkey =  [[NSUserDefaults standardUserDefaults] objectForKey:@"OAuthKey"];

    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?key=%@", attachment.attachmentURL,oauthkey]];
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setDownloadDestinationPath:[attachment getFileSystemPath]];
    

    _activeRequestCount++;
    
    if(_debugServerConnection){
        NSLog(@"File download started (%@) : %@ Active queries: %i",attachment.attachmentTitle, attachment.attachmentURL,_activeRequestCount);
    }
    
    //First request starts the network indicator
    if(_activeRequestCount==1) [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    [request startSynchronous];
    
    _activeRequestCount--;
    
    if(_debugServerConnection){
        NSLog(@"File download completed (%@) : %@ Active queries: %i",attachment.attachmentTitle,attachment.attachmentURL,_activeRequestCount);
    }
    
    //First request starts the network indicator
    if(_activeRequestCount==0) [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    //We need to do this in a different thread so that the current thread does not count towards the operations count
    [[ZPDataLayer instance] performSelectorInBackground:@selector(notifyAttachmentDownloadCompleted:) withObject:attachment];

}


@end
