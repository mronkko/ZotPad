//
//  ZPItemRetrieveOperation.m
//  ZotPad
//
//  Check the header file for documentation
//
//  See: Tutorial on NSOperation http://developer.apple.com/cocoa/managingconcurrency.html
//
//  Created by Rönkkö Mikko on 11/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPItemRetrieveOperation.h"

@implementation ZPItemRetrieveOperation

@synthesize itemIDs, libraryID, collectionKey, sortIsDescending, searchString, sortField;

// Calls the methods for retrieving data

-(void)main {
    if ( self.isCancelled ) return;
}

@end
