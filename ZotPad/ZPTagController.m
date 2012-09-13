//
//  ZPTagController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 9/13/12.
//
//

#import "ZPTagController.h"
#import "ZPItemListViewDataSource.h"
#import <QuartzCore/QuartzCore.h>

@implementation ZPTagController

- (void) configure{
    //Get the currently visible items
    NSArray* keysForVisibleItems = [[ZPItemListViewDataSource instance] itemKeys];
    _tags = [ZPDatabase tagsForItemKeys:keysForVisibleItems];
    _estimatedNumberOfRows = ([_tags count]+2)/3;
    _nextTagIndex = 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{

    NSString* identifier;
    BOOL hasTags;
    if(indexPath.section==0 || [_tags count] ==0 ){
        identifier = @"CellForNoTags";
        hasTags = FALSE;
    }
    else{
        identifier = @"CellWithTags";
        hasTags = TRUE;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

    if (cell == nil) {
        
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        
        if(! hasTags){
            cell.textLabel.center = cell.contentView.center;
            cell.textLabel.textColor = [UIColor grayColor];
            cell.textLabel.font = [UIFont systemFontOfSize:12];
            cell.textLabel.text = @"No tags";
        }

    }
    
    if(hasTags){
        //Clear existing tags
        for(UIView* view in cell.contentView.subviews){
            [view removeFromSuperview];
        }
        
        //Add tags to cell
        NSInteger xForNextTag=5;
        while (_nextTagIndex<[_tags count]) {
            
            //TODO: Recycle these labels
            UILabel* tagLabel = [[UILabel alloc] init];
            tagLabel.text = [_tags objectAtIndex:_nextTagIndex];
            [tagLabel sizeToFit];
            
            //If this is too large
            if(xForNextTag+tagLabel.frame.size.width > tableView.frame.size.width-5){
                if(xForNextTag==5){
                    tagLabel.frame = CGRectMake(5, 5, tableView.frame.size.width, tagLabel.frame.size.height-5);
                }
                else break;
            }
            
            //Position the tag
            tagLabel.frame = CGRectMake(xForNextTag, 5, tagLabel.frame.size.width+10, tagLabel.frame.size.height+10);

            //Modify looks
            tagLabel.backgroundColor = [UIColor yellowColor];
            tagLabel.layer.cornerRadius =  tagLabel.frame.size.height/2;
            
//            tagLabel.layer.borderWidth = 2;
            tagLabel.textAlignment = UITextAlignmentCenter;

            //Add the tag
            xForNextTag = xForNextTag + tagLabel.frame.size.width+10;
            [cell.contentView addSubview:tagLabel];
            DDLogVerbose(@"Adding tag %@ with frame %@",tagLabel.text,NSStringFromCGRect(tagLabel.frame));

            _nextTagIndex++;
        }
        
        //Update the estimated number of tags
        NSInteger difference = indexPath.row+1 + ([_tags count]-_nextTagIndex+2)/3 - _estimatedNumberOfRows;

        if(difference!=0){

            NSMutableArray* indexPaths = [[NSMutableArray alloc] initWithCapacity:abs(difference)];
            
            NSInteger lowerLimit = MIN(_estimatedNumberOfRows,_estimatedNumberOfRows + difference);
            NSInteger upperLimit = MAX(_estimatedNumberOfRows,_estimatedNumberOfRows + difference);
            
            for(NSInteger i = lowerLimit; i < upperLimit; i++){
                [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:indexPath.section]];
            }

            /*
            _estimatedNumberOfRows = _estimatedNumberOfRows + difference;

            if(difference<0){
                [tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            else if(difference>0){
                [tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            DDLogVerbose(@"Adjusting tag rows by %i , count now %i",difference,_estimatedNumberOfRows);
*/

        }
    }
    
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if(section==0){
        return 1;
    }
    else{
        return MAX(1,_estimatedNumberOfRows);
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if(section ==0){
        return @"Selected tags";
    }
    else{
        return @"Available tags";
    }
}

@end
