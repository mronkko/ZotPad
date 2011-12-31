//
//  ZPZoteroItemContainer.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/18/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPZoteroItemContainer : NSObject{
    NSString* _title;
    NSString* _key;
    NSNumber* _libraryID;
    BOOL _hasChildren;
    NSString* _lastCompletedCacheTimestamp;
    NSString* _serverTimestamp;
    NSInteger _numItems;
}
@property (retain) NSString* title;
@property (retain) NSNumber* libraryID;

// Important: This field stores the number of all items including items that are attachments to parent items. 

@property (assign) NSInteger numItems;
@property (assign) BOOL hasChildren;

@property (retain) NSString* lastCompletedCacheTimestamp;
@property (retain) NSString* serverTimestamp;

-(NSString*) collectionKey;

@end
