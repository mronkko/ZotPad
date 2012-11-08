//
//  ZPTagController.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 9/13/12.
//
//

#import "ZPTagController.h"
#import <QuartzCore/QuartzCore.h>

@interface ZPTagController()

+(NSInteger) _widthForTag:(NSString*)tag;
+(UIButton*) _tagButtonForTag:(NSString*)tag;

@end

static NSMutableArray* buttonCache;
static UIImage* blueBackgroundImage;

@implementation ZPTagController

static const NSInteger margin = 10;
static const NSInteger tagHeight = 30;
static const NSInteger tagWidthMultiplier = 6;
static const NSInteger tagBaseWidth = 20;

@synthesize tagOwner;

+(void) initialize{
    CGRect rect = CGRectMake(0, 0, 1, 1);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [[UIColor blueColor] CGColor]);
    CGContextFillRect(context, rect);
    blueBackgroundImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    buttonCache = [[NSMutableArray alloc] init];
}


- (id) init{
    self = [super init];
    return self;
}

- (void) prepareToShow{
    //Get the currently visible items
    _tags = [tagOwner availableTags];
    _indexOfFirstTagForEachRow = NULL;
}
- (void) prepareToHide{
    _tags = [tagOwner tags];
    _indexOfFirstTagForEachRow = NULL;
}

+(NSInteger) _widthForTag:(NSString*)tag{
    return [tag length]*tagWidthMultiplier+tagBaseWidth;
}

+(UIButton*) _tagButtonForTag:(NSString*)tag{
    
    UIButton* tagButton;
    if([buttonCache count]==0){
        tagButton = [UIButton buttonWithType:UIButtonTypeCustom];
        
        [tagButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [tagButton setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        [tagButton setBackgroundImage:blueBackgroundImage forState:UIControlStateSelected];
        tagButton.titleLabel.font = [UIFont boldSystemFontOfSize:10];
        
        
        CALayer * layer = tagButton.layer;
        [layer setMasksToBounds:YES];
        [layer setCornerRadius:tagHeight/2];
        [layer setBorderWidth:1.0];
        [layer setBorderColor:[[UIColor grayColor] CGColor]];
        
    }
    else{
        tagButton = [buttonCache lastObject];
        [buttonCache removeLastObject];
    }
    [tagButton setTitle:tag forState:UIControlStateNormal];
    
    
    tagButton.frame = CGRectMake(0,
                                 0,
                                 [self _widthForTag:tag],
                                 tagHeight);
    
    return tagButton;
}


+(void) addTagButtonsToView:(UIView*) view tags:(NSArray*)tags{
    
    //Recycle the existig tag buttons
    
    for(UIView* tagButton in view.subviews){
        [tagButton removeFromSuperview];
        [buttonCache addObject:tagButton];
    }
    
    NSInteger maxWidthOfTags = view.frame.size.width;

    //For some reason cell width is not always correct when displaying item details, so we need to hardcode a maximum width
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        maxWidthOfTags = MIN(maxWidthOfTags,600);
    }
    
    NSInteger x=10;
    NSInteger y=7;
    
    
    for(NSString* tag in tags){
        UIButton* tagButton = [ZPTagController _tagButtonForTag:tag];
        tagButton.selected = TRUE;
        tagButton.userInteractionEnabled = FALSE;
        
        if(x+tagButton.frame.size.width>maxWidthOfTags){
            if(x==10){
                tagButton.frame = CGRectMake(x, y, maxWidthOfTags, tagButton.frame.size.height);
                y=y+tagButton.frame.size.height+10;
            }
            else{
                x=10;
                y=y+tagButton.frame.size.height+10;
                tagButton.frame = CGRectMake(x, y, MIN(tagButton.frame.size.width, maxWidthOfTags), tagButton.frame.size.height);
                x=x+tagButton.frame.size.width+10;
                
            }
        }
        else{
            tagButton.frame = CGRectMake(x, y, MIN(tagButton.frame.size.width, maxWidthOfTags), tagButton.frame.size.height);
            x=x+tagButton.frame.size.width+10;
        }
        
        [view addSubview:tagButton];
        
    }

}


#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}



- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{

    
    //NSLog(@"Loading row %i",indexPath.row);
    
    NSString* identifier;
    BOOL hasTags;
    if([_tags count] ==0 ){
        identifier = @"NoTagsCell";
        hasTags = FALSE;
    }
    else{
        identifier = @"TagsCell";
        hasTags = TRUE;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    else{
        NSLog(@"Recycled cell %@ with %i subvies",cell,[cell.contentView.subviews count]);
        
        //Clear existing tags
        for(UIView* view in cell.contentView.subviews){
            [view removeFromSuperview];
            [buttonCache addObject:view];
        }

    }

    if(hasTags){
        

        
        NSInteger xForNextTag=margin;
        NSInteger startIndex = [[_indexOfFirstTagForEachRow objectAtIndex:indexPath.row] integerValue];
        NSInteger endIndex = (indexPath.row+1 == [_indexOfFirstTagForEachRow count] ? [_tags count]-1:
                              [[_indexOfFirstTagForEachRow objectAtIndex:indexPath.row+1] integerValue]-1) ;
        
        for(NSInteger index = startIndex; index<=endIndex;++index){
            
            NSString* tag = [_tags objectAtIndex:index];
            
            //Recycle buttons or create new
            
            UIButton* tagButton = [ZPTagController _tagButtonForTag:tag];


            [tagButton addTarget:self
                          action:@selector(toggleTag:)
                forControlEvents:UIControlEventTouchUpInside];

            tagButton.selected = [tagOwner isTagSelected:tag];

            //Position the tag
            tagButton.frame = CGRectMake(xForNextTag, margin/2, tagButton.frame.size.width, tagButton.frame.size.height);


            //Add the tag
            xForNextTag = xForNextTag + tagButton.frame.size.width+margin;
            [cell.contentView addSubview:tagButton];

        }
        
        //Optimize rendering
        cell.contentView.opaque = YES;
        cell.contentView.layer.shouldRasterize = YES;
        cell.contentView.layer.rasterizationScale = [UIScreen mainScreen].scale;

        NSLog(@"Configured cell %@ with %i subvies",cell, [cell.contentView.subviews count]);

    }

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{

    NSMutableArray* indices = [[NSMutableArray alloc] init];
    
    if(_indexOfFirstTagForEachRow == NULL){
        NSInteger x=margin;
        NSInteger index=0;
        BOOL firstInRow = TRUE;
        for(NSString* tag in _tags){

            NSInteger thisTagWidth = [ZPTagController _widthForTag:tag];
            
            if(firstInRow){
                [indices addObject:[NSNumber numberWithInt:index]];

                //Placement of the next tag
                x=margin+thisTagWidth+margin;
                firstInRow = x > tableView.frame.size.width;
            }
            else{
                x=x+thisTagWidth+margin;
                //If the tag would overflow, place on next row
                if(x > tableView.frame.size.width){
                    x=margin+thisTagWidth+margin;
                    [indices addObject:[NSNumber numberWithInt:index]];
                }
            }
            ++index;
        }
    }
    
    _indexOfFirstTagForEachRow = indices;
    
    return [_indexOfFirstTagForEachRow count];
}

-(NSInteger) numberOfSelectedTagRowsToShow:(UITableView*)tableView{
    return MIN(5,[self tableView:tableView numberOfRowsInSection:0]);
}


-(void) toggleTag:(UIButton*)tagButton{
    if(tagButton.isSelected){
        tagButton.selected = FALSE;
        [tagOwner deselectTag:tagButton.titleLabel.text];
    }
    else{
        tagButton.selected = TRUE;
        [tagOwner selectTag:tagButton.titleLabel.text];
    }
}

@end
