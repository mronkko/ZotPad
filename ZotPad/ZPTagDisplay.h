//
//  ZPTagDisplay.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 2/7/13.
//
//

#import <Foundation/Foundation.h>
#import "ZPCore.h"

@protocol ZPTagDisplay <NSObject>

-(void) refreshTagsFor:(ZPZoteroDataObject*) item;

@end
