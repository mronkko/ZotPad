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
    NSArray* _indexOfFirstTagForEachRow;
}

// The controller that will be updated when tags are changed
@property (nonatomic, retain) NSObject<ZPTagOwner>* tagOwner;

-(void) prepareToShow;
-(void) prepareToHide;
-(void) toggleTag:(UIButton*)tagButton;

-(NSInteger) numberOfSelectedTagRowsToShow:(UITableView*)tableView;

// Called from other table view data sources to lay out tags
+(void) addTagButtonsToView:(UIView*) view tags:(NSArray*)tags;
+(NSInteger) heightForTagRowForUITableView:(UITableView*) tableView withTags:(NSArray*) tags;


@end
