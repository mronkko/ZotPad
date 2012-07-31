//
//  ZPPreviewSource.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 7/20/12.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ZPPreviewSource <NSObject>

-(UIView*) sourceViewForQuickLook;

@end
