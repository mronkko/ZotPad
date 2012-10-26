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

static UIImage* blueBackgroundImage;
static NSMutableArray* tagButtonCache;

@synthesize itemListViewController;

+(void) initialize{
    CGRect rect = CGRectMake(0, 0, 1, 1);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [[UIColor blueColor] CGColor]);
    CGContextFillRect(context, rect);
    blueBackgroundImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    tagButtonCache = [[NSMutableArray alloc] init];
}

- (id) init{
    self = [super init];
    return self;
}

- (void) prepareToShow{
    //Get the currently visible items
    NSArray* keysForVisibleItems = [[ZPItemListViewDataSource instance] itemKeys];
    _tags = [ZPDatabase tagsForItemKeys:keysForVisibleItems];
    _estimatedNumberOfRows = ([_tags count]+2)/3;
    _currentNumberOfRows = _estimatedNumberOfRows;
    _nextTagIndex = 0;
    _tagRows = [[NSMutableArray alloc] init];
}
- (void) prepareToHide{
    _tags = [[ZPItemListViewDataSource instance] selectedTags];
    _estimatedNumberOfRows = ([_tags count]+2)/3;
    _currentNumberOfRows = _estimatedNumberOfRows;
    _nextTagIndex = 0;
    _tagRows = [[NSMutableArray alloc] init];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{

//    NSLog(@"Loading row %i",indexPath.row);
    
    NSString* identifier;
    BOOL hasTags;
    if([_tags count] ==0 ){
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
            [tagButtonCache addObject:view];
        }
        
        //Add tags to cell
        NSInteger xForNextTag=5;
        
        //If the tags have already been laid out for this row, use them.
        NSMutableArray* tagsForThisRow;
        BOOL tagsLaidOutPreviously;
        if([_tagRows count]>indexPath.row){
            tagsForThisRow = [_tagRows objectAtIndex:indexPath.row];
            tagsLaidOutPreviously=TRUE;
        }
        else{
            tagsLaidOutPreviously=FALSE;
            tagsForThisRow = [[NSMutableArray alloc] init];
            [_tagRows addObject:tagsForThisRow];
        }
        
        //Else fill the row until it is full or all tags are showing, or as long as we have tags that have been laid out previously
        
        NSInteger indexForThisTagRow = 0;
        
        while (tagsLaidOutPreviously ? indexForThisTagRow < [tagsForThisRow count]: _nextTagIndex<[_tags count]) {
            
            NSString* tag;
            
            if(tagsLaidOutPreviously){
                tag = [tagsForThisRow objectAtIndex:indexForThisTagRow];
                indexForThisTagRow++;
            }
            else{
                tag = [_tags objectAtIndex:_nextTagIndex];
            }
            

            //Recycle buttons or create new
            
            UIButton* tagButton;

            NSInteger margin = 20;

            if([tagButtonCache count]>0){

//                NSLog(@"Reusing Button: Tag %@",tag);

                tagButton = [tagButtonCache lastObject];
                [tagButtonCache removeLastObject];

                [tagButton setTitle:tag forState:UIControlStateNormal];
                [tagButton sizeToFit];
                
                tagButton.frame = CGRectMake(tagButton.frame.origin.x,
                                             tagButton.frame.origin.y,
                                             tagButton.frame.size.width+margin,
                                             tagButton.frame.size.height+margin);
            }
            else{

//                NSLog(@"New Button: Tag %@",tag);

                tagButton = [UIButton buttonWithType:UIButtonTypeCustom];
                
                [tagButton addTarget:self
                              action:@selector(toggleTag:)
                    forControlEvents:UIControlEventTouchUpInside];
                
                [tagButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
                [tagButton setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
                [tagButton setBackgroundImage:blueBackgroundImage forState:UIControlStateSelected];
                tagButton.titleLabel.font = [UIFont boldSystemFontOfSize:10];
                
                [tagButton setTitle:tag forState:UIControlStateNormal];
                [tagButton sizeToFit];
                
                tagButton.frame = CGRectMake(tagButton.frame.origin.x,
                                             tagButton.frame.origin.y,
                                             tagButton.frame.size.width+margin,
                                             tagButton.frame.size.height+margin);

                //Configure the looks of the button. This must be done after sizeToFit
                CALayer * layer = tagButton.layer;
                [layer setMasksToBounds:YES];
                [layer setCornerRadius:tagButton.frame.size.height/2];
                [layer setBorderWidth:1.0];
                [layer setBorderColor:[[UIColor grayColor] CGColor]];
            }

            tagButton.selected = [[ZPItemListViewDataSource instance] isTagSelected:tag];

            
            //If this is too large
            if(xForNextTag+tagButton.frame.size.width > tableView.frame.size.width-5){
                if(xForNextTag==5 || tagsLaidOutPreviously){
                    tagButton.frame = CGRectMake(5, 5, tableView.frame.size.width-10, tagButton.frame.size.height);
                }
                //This is simply too large tag, leave it to the next row
                else break;
            }
            
            //Position the tag
            tagButton.frame = CGRectMake(xForNextTag, 5, tagButton.frame.size.width, tagButton.frame.size.height);


            //Add the tag
            xForNextTag = xForNextTag + tagButton.frame.size.width+10;
            [cell.contentView addSubview:tagButton];

            if(!tagsLaidOutPreviously){
                [tagsForThisRow addObject:tag];
                _nextTagIndex++;
            }
        }
        
        if(!tagsLaidOutPreviously){
            //Update the estimated number of tags and number of rows in the table
            NSInteger difference = indexPath.row+1 + ([_tags count]-_nextTagIndex+2)/3 - _estimatedNumberOfRows;
            
            if(difference!=0){
                
                _estimatedNumberOfRows = _estimatedNumberOfRows + difference;
                
                // If this is the last cell and the estimated number of rows differs from the current rows, increase the size of the table
                // Or if all the tags have been laid out and the estimated number differs, delete rows
                
                if(_estimatedNumberOfRows != _currentNumberOfRows &&
                   (indexPath.row==_currentNumberOfRows-1 ||
                    _nextTagIndex>=[_tags count])){
                    
                       difference = _estimatedNumberOfRows - _currentNumberOfRows;

                       NSLog(@"Updating the number of rows in tag selector by %i, previous rows: %i new rows: %i",difference,_currentNumberOfRows,_estimatedNumberOfRows);

                       NSMutableArray* indexPaths = [[NSMutableArray alloc] initWithCapacity:abs(difference)];
                       
                       NSInteger lowerLimit = MIN(_currentNumberOfRows,_estimatedNumberOfRows);
                       NSInteger upperLimit = MAX(_currentNumberOfRows,_estimatedNumberOfRows);
                       
                       for(NSInteger i = lowerLimit; i < upperLimit; i++){
                           [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:indexPath.section]];
                       }

                       _currentNumberOfRows = _estimatedNumberOfRows;
                       
                       if(difference<0){
                           [tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
                       }
                       else{
                           [tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
                       }
                   }
            }
        }
    }

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return MAX(1,_currentNumberOfRows);
}

-(NSInteger) numberOfSelectedTagRowsToShow:(UITableView*)tableView{

    if([_tags count]==0) return 0;
    
    //Lay out up to 5 rows of the table
    
    for(NSInteger index=0;index<5;++index){
        [self tableView:tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
         //If this number of rows is sufficient to show all the tags
        if(_nextTagIndex>=[_tags count]){
            return index+1;
        }
    }
    return 5;
}


-(void) toggleTag:(UIButton*)tagButton{
    if(tagButton.isSelected){
        tagButton.selected = FALSE;
        [[ZPItemListViewDataSource instance] deselectTag:tagButton.titleLabel.text];
    }
    else{
        tagButton.selected = TRUE;
        [[ZPItemListViewDataSource instance] selectTag:tagButton.titleLabel.text];
    }

    if (self.itemListViewController != NULL) {
        [self.itemListViewController configureView];
    }

}

@end
