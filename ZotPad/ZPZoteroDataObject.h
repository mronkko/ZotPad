//
//  ZPZoteroItemContainer.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/18/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPZoteroDataObject : NSObject{
}

// This is very useful for troubleshooting, but because of memory issues, is only used for debug builds
#ifdef ZPDEBUG
//@property (retain) NSString* responseDataFromWhichThisItemWasCreated;
#endif

@property (retain) NSString* title;
@property (assign) NSInteger libraryID;
@property (retain) NSString* key;
@property (retain) NSString* dateAdded;

// Important: This field stores the number of all items including items that are attachments to parent items. 

@property (assign) NSInteger numChildren;
@property (assign, readonly) BOOL hasChildren;

@property (retain) NSString* cacheTimestamp;
@property (retain) NSString* serverTimestamp;

-(void) configureWithDictionary:(NSDictionary*) dictionary;
-(BOOL) needsToBeWrittenToCache;

@end
