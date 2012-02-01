//
//  ZPZoteroItemContainer.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/18/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPZoteroDataObject : NSObject{
    NSString* _title;
    NSString* _key;
    NSNumber* _libraryID;
    BOOL _hasChildren;
    NSString* _cacheTimestamp;
    NSString* _serverTimestamp;
    NSInteger _numItems;
}
@property (retain) NSString* title;
@property (retain, readonly) NSNumber* libraryID;
@property (retain, readonly) NSString* key;

// Important: This field stores the number of all items including items that are attachments to parent items. 

@property (assign) NSInteger numItems;
@property (assign, readonly) BOOL hasChildren;

@property (retain) NSString* cacheTimestamp;
@property (retain) NSString* serverTimestamp;

+(id) dataObjectWithKey:(NSObject*) key;
-(void) configureWithDictionary:(NSDictionary*) dictionary;
-(BOOL) needsToBeWrittenToCache;

@end
