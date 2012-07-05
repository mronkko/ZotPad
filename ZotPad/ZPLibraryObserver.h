//
//  ZPLibraryObserver.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/16/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPZoteroLibrary.h"
@protocol ZPLibraryObserver <NSObject>

// Tells an observer that a library and all its collections are now available
-(void) notifyLibraryWithCollectionsAvailable:(ZPZoteroLibrary*) library;

@end
