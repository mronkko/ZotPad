//
//  ZPTagOwner.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/3/12.
//
//

#import <Foundation/Foundation.h>

@protocol ZPTagOwner <NSObject>

-(NSArray*) tags;
-(NSArray*) availableTags;
-(void) selectTag:(NSString*)tag;
-(void) deselectTag:(NSString*)tag;
-(BOOL) isTagSelected:(NSString*)tag;

@end
