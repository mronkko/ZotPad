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
    BOOL    _collectionsSynced;
}

// This class is used as a singleton
+ (ZPDataLayer*) instance;

- (NSArray*) libraries;
- (NSArray*) collections : (NSInteger)currentLibraryID currentCollection:(NSInteger)currentCollectionID;

- (NSArray*) getItemIDsForView:(ZPDetailViewController*)view;
- (NSDictionary*) getFieldsForItem: (NSInteger) itemID;
- (NSArray*) getCreatorsForItem: (NSInteger) itemID;
- (NSArray*) getAttachmentFilePathsForItem: (NSInteger) itemID;


// Helper functions to prepare and execute statements. All SQL queries should be done through these

-(sqlite3_stmt*) prepareStatement:(NSString*) sqlString;
-(void) executeStatement:(NSString*) sqlString;

@end
