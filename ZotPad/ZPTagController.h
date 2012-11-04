//
//  ZPTagController.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 9/13/12.
//
//

#import <Foundation/Foundation.h>
#import "ZPTagOwner.h"

@interface ZPTagController : NSObject <UITableViewDataSource>{
    NSArray* _tags;
    NSInteger _estimatedNumberOfRows;
    NSInteger _currentNumberOfRows;
    NSInteger _nextTagIndex;
    NSMutableArray* _tagRows;
}

// The controller that will be updated when tags are changed
@property (nonatomic, retain) NSObject<ZPTagOwner>* tagOwner;

-(void) prepareToShow;
-(void) prepareToHide;
-(void) toggleTag:(UIButton*)tagButton;
-(NSInteger) numberOfSelectedTagRowsToShow:(UITableView*)tableView;
+(UIButton*) tagButtonForTag:(NSString*)tag;

@end
