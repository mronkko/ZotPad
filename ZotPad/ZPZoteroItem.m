//
//  ZPZoteroItem.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ZPZoteroItem.h"

@implementation ZPZoteroItem

@synthesize title;
@synthesize key;
@synthesize authors;
@synthesize year;
@synthesize libraryID;
@synthesize hasChildren;
@synthesize formattedCitation;
@synthesize itemType;
@synthesize creatorSummary;
@synthesize numChildren;
@synthesize numTags;

-(void) setNumChildren:(NSString*)numChildren{
    [self setNumChildren:[numChildren intValue]];
}
-(void) setNumTags:(NSString*)numTags{
    [self setNumTags:[numTags intValue]];
}

@end
