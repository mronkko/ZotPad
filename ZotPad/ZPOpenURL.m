//
//  ZPOpenURL.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 12/29/12.
//
//

#import "ZPOpenURL.h"
#import "ZPDate.h"


@implementation ZPOpenURL

@synthesize genre, metadata, atitle, jtitle, stitle, volume, issue, btitle, inst, assignee, number;

-(NSString*) version{
    return @"1.0";
}

-(id) initWithZoteroItem:(ZPZoteroItem *)item{
    self = [super init];
    
    
    if([item.itemType isEqualToString: @"journalArticle"]) {
        self.metadata = @"info:ofi/fmt:kev:mtx:journal";
        self.genre = @"article";
        self.atitle = item.title;
        self.jtitle = item.publicationTitle;
        self.stitle = item.journalAbbreviation;
        self.volume = item.volume;
        self.issue = item.issue;
    }
    else if([item.itemType isEqualToString: @"book"] || [item.itemType isEqualToString: @"bookSection"] || [item.itemType isEqualToString: @"conferencePaper"]) {
        self.metadata = @"info:ofi/fmt:kev:mtx:book";
        
        if([item.itemType isEqualToString: @"book"]) {
            self.genre = @"book";
            self.btitle = item.title;
        }
        else if ([item.itemType isEqualToString: @"conferencePaper"]) {
            self.genre = @"proceeding";
            self.atitle = item.title;
            self.btitle = item.proceedingsTitle;
            
        }
        else {
            self.genre = @"bookitem";
            self.atitle = item.title;
            self.btitle = item.publicationTitle;
        }
        
        self.place = item.place;
        self.publisher = item.publisher;
        self.edition = item.edition;
        self.series = item.series;
    }
    else if([item.itemType isEqualToString: @"thesis"]) {
        self.metadata = @"info:ofi/fmt:kev:mtx:dissertation";
        
        self.title = item.title;
        self.inst = item.publisher;
        self.degree = item.type;
        
    }
    else if([item.itemType isEqualToString: @"patent"]) {
        
        self.metadata = @"info:ofi/fmt:kev:mtx:patent";
        
        self.title = item.title;
        self.assignee = item.assignee;
        self.number = item.patentNumber;
        
        self.date =  [[ZPDate strToDate:item.issueDate] ISOString];
    }
    else {
        [NSException raise:@"Unsupported" format:@"OpenURL does not support item type %@",item.itemType];
    }
    
    if(item.creators && item.creators.length) {
        // encode first author as first and last
        NSDictionary* firstCreator = [item.creators objectAtIndex:0];
        
        if([item.itemType isEqualToString: @"patent"]) {
            self.invfirst = [firstCreator objectForKey:@"firstName"];
            self.invlast = [firstCreator objectForKey:@"lastName"];
        }
        else {
            if([firstCreator objectForKey:@"fullName"]) {
                self.aucorp = [firstCreator objectForKey:@"fullName"];
            } else {
                self.aufirst = [firstCreator objectForKey:@"firstName"];
                self.aullast = [firstCreator objectForKey:@"lastName"];
            }
        }
        
        //TODO: Implement rest of the authors if needed
    }
    
    if(item.date) {
        NSString* ISODate [[ZPDate strToDate:item.date] ISOString];
        if([item.itemType isEqualToString: @"patent"]) self.appldate = ISODate;
        else self.date = ISODate;
    }
    if(item.pages) {
        self.pages = item.pages;
        NSArray* pages = [self.pages componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"[-–]"]];
        
        if(pages.length > 1) {
            self.spage = [pages objectAtIndex:0]
            if(pages.length >= 2) self.epage = [pages objectAtIndex:1];
        }
    }
    if(item.numPages) self.tpages = item.numPages;
    if(item.ISBN) self.isbn = item.ISBN;
    if(item.ISSN) self.issn = item.ISSN;
    
}


@end
