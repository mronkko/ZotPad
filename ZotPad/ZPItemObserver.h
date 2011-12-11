//
//  ZPItemObserver.h
//  ZotPad
//
//
//  Objects that implement this protocol can be observers that are 
//  Notified when new items become available
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ZPItemObserver <NSObject>

@optional
// Tells an observer that the array containing items for the visible item set has been updated
-(void) notifyItemKeysAvailableForVisibleSet;

// Tells an observer that basic citation information is available for items
-(void) notifyItemBasicsAvailable:(NSArray*) keys;

// Tells an observer that detailed citation information is available
-(void) notifyItemDetailsAvailable:(NSArray*) keys;

// Tells an observer that information about attachments is available
-(void) notifyItemAttachmentInformationAvailable:(NSstring*) key;

// Tells an observer that information about attachments is available
-(void) notifyItemAttachmentFileAvailable:(NSString*) path;

@end
