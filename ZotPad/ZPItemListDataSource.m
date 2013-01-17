//
//  ZPItemListDataSource.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 1/15/13.
//
//

#import "ZPCore.h"
#import "ZPItemListDataSource.h"

#import "ZPAttachmentIconImageFactory.h"
#import "ZPReachability.h"
#import "ZPFileViewerViewController.h"

//Rendering formatted text, needed for iOS 5 compatibility
#import "DTCoreText.h"
#import "OHAttributedLabel.h"


@implementation ZPItemListDataSource

@synthesize contentArray;

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section. Initially there is no library selected, so we will just return an empty view
    NSInteger count=1;
    if(self.contentArray!=nil){
        count= MAX(1,[self.contentArray count]);
    }
    return count;
}


- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell* cell;
    
    if(indexPath.row>=[self.contentArray count]){
        NSString* identifier = @"NoItemsCell";
/*        if(_libraryID==0){
            identifier = @"ChooseLibraryCell";
        }
        else if(_invalidated){
            identifier = @"BlankCell";
        }
        else{
            identifier;
        }
        //DDLogVerbose(@"Cell identifier is %@",identifier);
*/
        cell = [aTableView dequeueReusableCellWithIdentifier:identifier];
        if(cell == nil) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        
    }
    else{
        NSObject* keyObj = [self.contentArray objectAtIndex: indexPath.row];

        NSString* key;
        if(keyObj==[NSNull null] || keyObj==NULL){
            key=@"";
        }
        else{
            key= (NSString*) keyObj;
        }
        
        ZPZoteroItem* item=NULL;
        if(![key isEqualToString:@""]) item = (ZPZoteroItem*) [ZPZoteroItem itemWithKey:key];
        
        if(item==NULL){
            cell = [aTableView dequeueReusableCellWithIdentifier:@"LoadingCell"];
            //Togle the actiity view on
            [(UIActivityIndicatorView*) [cell viewWithTag:1] startAnimating];
        }
        else{
            cell = [aTableView dequeueReusableCellWithIdentifier:@"ZoteroItemCell"];
            //DDLogVerbose(@"Cell identifier is ZoteroItemCell");
            //DDLogVerbose(@"Item with key %@ has full citation %@",item.key,item.fullCitation);
            
            UILabel *titleLabel = (UILabel *)[cell viewWithTag:1];
            titleLabel.text = item.title;
            
            UILabel *authorsLabel = (UILabel *)[cell viewWithTag:2];
            
            authorsLabel.text = item.creatorSummary;
            
            //Publication as a formatted label
            
            OHAttributedLabel* publishedInLabel = (OHAttributedLabel*)[cell viewWithTag:3];
            
            
            
            if(publishedInLabel != NULL){
                
                publishedInLabel.automaticallyAddLinksForType = 0;
                
                NSString* publishedIn = item.publicationDetails;
                
                if(publishedIn == NULL){
                    publishedIn=@"";
                }
                
                NSAttributedString* text = [[NSAttributedString alloc] initWithHTMLData:[publishedIn dataUsingEncoding:NSUTF8StringEncoding]  documentAttributes:NULL];
                
                //Font size of TTStyledTextLabel cannot be set in interface builder, so must be done here
                [publishedInLabel setFont:[UIFont systemFontOfSize:[UIFont smallSystemFontSize]]];
                [publishedInLabel setAttributedText:text];
            }
            
            //The item key for troubleshooting
            UILabel* keyLabel = (UILabel*) [cell viewWithTag:5];
            if([ZPPreferences displayItemKeys]){
                keyLabel.hidden = FALSE;
                keyLabel.text = item.key;
            }
            else{
                keyLabel.hidden = TRUE;
            }
            
            //Attachment icon
            
            UIImageView* articleThumbnail = (UIImageView *) [cell viewWithTag:4];
            
            //Remove subviews. These can be used when rendering.
            for(UIView* view in articleThumbnail.subviews) [view removeFromSuperview];
            
            //Check if the item has attachments and render a thumbnail from the first attachment PDF
            
            if(articleThumbnail!= NULL){
                if([item.attachments count] > 0){
                    
                    [articleThumbnail setHidden:FALSE];
                    
                    ZPZoteroAttachment* attachment = [item.attachments objectAtIndex:0];
                    
                    
                    //DDLogVerbose(@"ImageView for row %i is %i",indexPath.row,articleThumbnail);
                    
                    [ZPAttachmentIconImageFactory renderFileTypeIconForAttachment:attachment intoImageView:articleThumbnail];
                    // Enable or disable depending whether file is available or not
                    
                    if(attachment.fileExists || (attachment.linkMode == LINK_MODE_LINKED_URL && [ZPReachability hasInternetConnection])){
                        articleThumbnail.alpha = 1;
                        articleThumbnail.userInteractionEnabled = TRUE;
                        
                        //If there is no gesture recognizer, create and add one
                        if(articleThumbnail.gestureRecognizers.count ==0){
                            [articleThumbnail addGestureRecognizer: [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(attachmentThumbnailPressed:)]];
                        }
                    }
                    else{
                        articleThumbnail.alpha = .3;
                        articleThumbnail.userInteractionEnabled = FALSE;
                    }
                }
                else{
                    articleThumbnail.hidden=TRUE;
                }
            }
            
        }
    }
    if(cell == NULL || ! [cell isKindOfClass:[UITableViewCell class]]){
        [NSException raise:@"Invalid cell" format:@""];
    }
    
    return cell;
}

-(IBAction) attachmentThumbnailPressed:(id)sender{
    
    //Get the table cell.
    UITapGestureRecognizer* gr = (UITapGestureRecognizer*)  sender;
    UIView* imageView = [gr view];
    UITableViewCell* cell = (UITableViewCell* )[[imageView superview] superview];
    
    //Get the row of this cell
    NSIndexPath* indexPath = [(UITableView*)cell.superview indexPathForCell:cell];
    NSInteger row = indexPath.row;
    
    ZPZoteroItem* item = (ZPZoteroItem*) [ZPZoteroItem itemWithKey:[self.contentArray objectAtIndex:row]];
    
    ZPZoteroAttachment* attachment = [item.attachments objectAtIndex:0];
    
    if(attachment.linkMode == LINK_MODE_LINKED_URL && [ZPReachability hasInternetConnection]){
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:attachment.url]];
    }
    else{
        [ZPFileViewerViewController presentWithAttachment:attachment];
    }
}
@end
