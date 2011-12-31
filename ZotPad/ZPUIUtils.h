//
//  ZPUIUtils.h
//  ZotPad
//
//  Contains miscellanneous static methods than are used in rendering the UI
// 
//
//  Created by Rönkkö Mikko on 12/29/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPUIUtils : NSObject

+(UIImageView*)renderThumbnailFromPDFFile:(NSString*)filename maxHeight:(NSInteger)maxHeight maxWidth:(NSInteger)maxWidth;

@end
