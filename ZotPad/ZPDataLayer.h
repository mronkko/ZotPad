//
//  ZPDataLayer.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import "ZPDetailViewController.h"

@interface ZPDataLayer : NSObject {
	sqlite3 *database;
}

// This class is used as a singleton
+ (ZPDataLayer*) instance;

- (NSArray*) libraries;
- (NSArray*) collections : (NSInteger)currentLibraryID currentCollection:(NSInteger)currentCollectionID;

- (NSArray*) getItemIDsForView:(ZPDetailViewController*)view;
- (NSDictionary*) getFieldsForItem: (NSInteger) itemID;
- (NSArray*) getCreatorsForItem: (NSInteger) itemID;
- (NSArray*) getAttachmentFilePathsForItem: (NSInteger) itemID;

@end
