//
//  ZPUserSupport.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 7/25/13.
//
//

#import <Foundation/Foundation.h>

@interface ZPUserSupport : NSObject

+(void) openSupportSystemWithArticleID:(NSInteger)articleId fromParentViewController:(UIViewController*)viewController;
+(void) openSupportSystemFromParentViewController:(UIViewController*)viewController;

@end
