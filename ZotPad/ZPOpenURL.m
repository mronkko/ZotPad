//
//  ZPOpenURL.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 12/29/12.
//
//

#import "ZPOpenURL.h"
#import "ZPDate.h"
#import "NSString+URLEncoding.h"

@interface ZPOpenURL(){
    NSMutableDictionary* _fields;
}

-(void) _setObject:(NSObject*) obj forKey:(NSString*)key;

@end

@implementation ZPOpenURL

@synthesize fields = _fields;

-(NSString*) version{
    return @"1.0";
}

-(id) initWithZoteroItem:(ZPZoteroItem *)item{
    self = [super init];
    
    _fields = [[NSMutableDictionary alloc] init];
    
    if([item.itemType isEqualToString: @"journalArticle"]) {
        [self _setObject:@"info:ofi/fmt:kev:mtx:journal" forKey:@"rft_val_fmt"];
        [self _setObject:@"article" forKey:@"genre"];
        [self _setObject:item.title forKey:@"atitle"];
        [self _setObject:[item.fields objectForKey:@"publicationTitle"] forKey:@"jtitle"];
        [self _setObject:[item.fields objectForKey:@"journalAbbreviation"] forKey:@"stitle"];
        [self _setObject:[item.fields objectForKey:@"volume"] forKey:@"volume"];
        [self _setObject:[item.fields objectForKey:@"issue"] forKey:@"issue"];
    }
    else if([item.itemType isEqualToString: @"book"] || [item.itemType isEqualToString: @"bookSection"] || [item.itemType isEqualToString: @"conferencePaper"]) {
        [self _setObject:@"info:ofi/fmt:kev:mtx:book" forKey:@"rft_val_fmt"];
        
        if([item.itemType isEqualToString: @"book"]) {
            [self _setObject:@"book" forKey:@"genre"];
            [self _setObject:item.title forKey:@"btitle"];
        }
        else if ([item.itemType isEqualToString: @"conferencePaper"]) {
            [self _setObject:@"proceeding" forKey:@"genre"];
            [self _setObject:item.title forKey:@"atitle"];
            [self _setObject:[item.fields objectForKey:@"proceedingsTitle"] forKey:@"btitle"];
            
        }
        else {
            [self _setObject:@"bookitem" forKey:@"genre"];
            [self _setObject:item.title forKey:@"atitle"];
            [self _setObject:[item.fields objectForKey:@"publicationTitle"] forKey:@"btitle"];
        }
        
        [self _setObject:[item.fields objectForKey:@"place"] forKey:@"place"];
        [self _setObject:[item.fields objectForKey:@"publisher"] forKey:@"publisher"];
        [self _setObject:[item.fields objectForKey:@"edition"] forKey:@"edition"];
        [self _setObject:[item.fields objectForKey:@"series"] forKey:@"series"];
    }
    else if([item.itemType isEqualToString: @"thesis"]) {
        [self _setObject:@"info:ofi/fmt:kev:mtx:dissertation" forKey:@"rft_val_fmt"];
        
        [self _setObject:item.title forKey:@"title"];
        [self _setObject:[item.fields objectForKey:@"publisher"] forKey:@"inst"];
        [self _setObject:[item.fields objectForKey:@"type"] forKey:@"degree"];
        
    }
    else if([item.itemType isEqualToString: @"patent"]) {
        
        [self _setObject:@"info:ofi/fmt:kev:mtx:patent" forKey:@"rft_val_fmt"];
        
        [self _setObject:item.title forKey:@"title"];
        [self _setObject:[item.fields objectForKey:@"assignee"] forKey:@"assignee"];
        [self _setObject:[item.fields objectForKey:@"patentNumber"] forKey:@"number"];
        
        [self _setObject:[[ZPDate strToDate:[item.fields objectForKey:@"issueDate"]] ISOString] forKey:@"date"];
    }
    else {
        [NSException raise:@"Unsupported" format:@"OpenURL does not support item type %@",item.itemType];
    }
    
    if(item.creators && item.creators.count) {
        // encode first author as first and last
        NSDictionary* firstCreator = [item.creators objectAtIndex:0];
        
        if([item.itemType isEqualToString: @"patent"]) {
            [self _setObject:[firstCreator objectForKey:@"firstName"] forKey:@"invfirst"];
            [self _setObject:[firstCreator objectForKey:@"lastName"] forKey:@"invlast"];
        }
        else {
            if([firstCreator objectForKey:@"fullName"]) {
                [self _setObject:[firstCreator objectForKey:@"fullName"] forKey:@"aucorp"];
            } else {
                [self _setObject:[firstCreator objectForKey:@"firstName"] forKey:@"aufirst"];
                [self _setObject:[firstCreator objectForKey:@"lastName"] forKey:@"aullast"];
            }
        }
        
        //TODO: Implement rest of the authors if needed
    }
    
    if([item.fields objectForKey:@"date"]) {
        NSString* ISODate = [[ZPDate strToDate:[item.fields objectForKey:@"date"]] ISOString];
        if([item.itemType isEqualToString: @"patent"]) [self _setObject:ISODate forKey:@"appldate"];
        else [self _setObject:ISODate forKey:@"date"];
    }
    if([item.fields objectForKey:@"pages"]) {
        [self _setObject:[item.fields objectForKey:@"pages"] forKey:@"pages"];
        NSArray* pages = [[item.fields objectForKey:@"pages"] componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"[-–]"]];
        
        if(pages.count > 1) {
            [self _setObject:[pages objectAtIndex:0] forKey:@"spage"];
            if(pages.count >= 2) [self _setObject:[pages objectAtIndex:1] forKey:@"epage"];
        }
    }
    if([item.fields objectForKey:@"numPages"]) [self _setObject:[item.fields objectForKey:@"numPages"] forKey:@"tpages"];
    if([item.fields objectForKey:@"ISBN"]) [self _setObject:[item.fields objectForKey:@"ISBN"] forKey:@"isbn"];
    if([item.fields objectForKey:@"ISSN"]) [self _setObject:[item.fields objectForKey:@"ISSN"] forKey:@"issn"];
    
    return self;
}

-(NSString*) URLString{
    
    NSMutableString* urlString = [NSMutableString stringWithString:@"url_ver=Z39.88-2004&ctx_ver=Z39.88-2004&rfr_id=info%3Asid%2Fzotpad.com%3A2"];
    
    for(NSString* key in _fields){

        NSString* value = [_fields objectForKey:key];

        if([key isEqualToString:@"rft_val_fmt"]){
            [urlString appendFormat:@"&%@=%@",key,value];
        }
        else{
            [urlString appendFormat:@"&rft.%@=%@",key,[value encodedURLString]];
        }
    }
    return urlString;
}

-(void) _setObject:(NSObject*) obj forKey:(NSString*)key{
    if(obj!=NULL){
        [_fields setObject:obj forKey:key];
    }

}

@end
