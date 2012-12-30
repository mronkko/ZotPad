//
//  ZPDate.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 12/30/12.
//
//

#import "ZPCore.h"
#import "ZPDate.h"

@implementation ZPDate

@synthesize year, month, day;

static NSRegularExpression* _slashRe;
static NSRegularExpression* _yearRe;

+(void) initialize{
    _slashRe = [NSRegularExpression regularExpressionWithPattern:@"^(.*?)\\b([0-9]{1,4})(?:([\\-\\/\\.\\u5e74])([0-9]{1,2}))?(?:([\\-\\/\\.\\u6708])([0-9]{1,4}))?((?:\\b|[^0-9]).*?)$" options:0 error:NULL];
    _yearRe = [NSRegularExpression regularExpressionWithPattern:@"^(.*?)\\b((?:circa |around |about |c\\.? ?)?[0-9]{1,4}(?: ?B\\.? ?C\\.?(?: ?E\\.?)?| ?C\\.? ?E\\.?| ?A\\.? ?D\\.?)|[0-9]{3,4})\\b(.*?)$" options:NSRegularExpressionCaseInsensitive error:NULL];
    
}
+(ZPDate*) strToDate:(NSString *)dateString{
    
    ZPDate* date = [[ZPDate alloc] init];
    
    // Strip white space
    dateString = [dateString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // Replace all white space with spaces
    NSArray* parts = [dateString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray* filteredArray = [parts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != ''"]];
    dateString = [filteredArray componentsJoinedByString:@" "];
    
    // first, directly inspect the string
    NSArray* m = [_slashRe matchesInString:dateString
                                   options:0
                                     range:NSMakeRange(0, [dateString length])];
    
    if(m &&
       ((![m objectAtIndex:5] || ![m objectAtIndex:3]) ||
        [[m objectAtIndex:3] isEqualToString: [m objectAtIndex:5]] ||
        ([[m objectAtIndex:3] isEqualToString: @"\u5e74"] && [[m objectAtIndex:5] isEqualToString: @"\u6708"])) &&	// require sane separators
       (([m objectAtIndex:2] && [m objectAtIndex:4] && [m objectAtIndex:6]) || (![m objectAtIndex:1] && ![m objectAtIndex:7]))) {						// require that either all parts are found,
        // or else this is the entire date field
        // figure out date based on parts
        if([(NSString*)[m objectAtIndex:2] length] == 3 || [(NSString*)[m objectAtIndex:2] length] == 4 || [[m objectAtIndex:3] isEqualToString: @"\u5e74"]) {
            // ISO 8601 style date (big endian)
            date.year = [[m objectAtIndex:2] integerValue];
            date.month = [[m objectAtIndex:4] integerValue];
            date.day = [[m objectAtIndex:6] integerValue];
        } else if([m objectAtIndex:2] && ![m objectAtIndex:4] && [m objectAtIndex:6]) {
            date.month = [[m objectAtIndex:2] integerValue];
            date.year = [[m objectAtIndex:6] integerValue];
        } else {
            //TODO: Implement date locales if needed
            date.month = [[m objectAtIndex:4] integerValue];
            date.day = [[m objectAtIndex:2] integerValue];
        }
        
        if(date.month) {
            if(date.month > 12) {
                // swap day and month
                NSInteger tmp = date.day;
                date.day = date.month;
                date.month = tmp;
            }
        }
        
        if((!date.month || date.month <= 12) && (!date.day || date.day <= 31)) {
            if(date.year && date.year < 100) {	// for two digit years, determine proper
                // four digit year
                NSInteger year = [[[NSCalendar currentCalendar]
                                   components:NSYearCalendarUnit fromDate:[NSDate date]]
                                  year];
                NSInteger twoDigitYear = year % 100;
                NSInteger century = year - twoDigitYear;
                
                if(date.year <= twoDigitYear) {
                    // assume this date is from our century
                    date.year = century + date.year;
                }
                else {
                    // assume this date is from the previous century
                    date.year = century - 100 + date.year;
                }
            }
            
        } else {
            // give up; we failed the sanity check
            DDLogVerbose(@"DATE: algorithms failed sanity check (%@)",dateString);
        }
    }
    else {
        DDLogVerbose(@"DATE: could not apply algorithms (%@)",dateString);
    }
    
    // couldn't find something with the algorithms; use regexp
    // YEAR
    if(!date.year) {
        NSArray* m = [_yearRe matchesInString:dateString
                                      options:0
                                        range:NSMakeRange(0, [dateString length])];
        if(m) {
            date.year = [[m objectAtIndex:2] integerValue];
        }
    }
    
    //TODO: Implement Month and Day if needed.
    
    return date;
}

-(NSString*) ISOString{
    
    
    if(self.year) {
        NSString* dateString = [NSString stringWithFormat:@"%000i", self.year];
        if(self.month) {
            dateString = [NSString stringWithFormat:@"%@-%0i", dateString, self.month];
            if(self.day) {
                dateString = [NSString stringWithFormat:@"%@-%0i", dateString, self.day];
            }
        }
        return dateString;
    }
    return NULL;
}


@end
