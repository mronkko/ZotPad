//
//  ZPOpenURL.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 12/29/12.
//
//
#import "ZPCore.h"
#import <Foundation/Foundation.h>

@interface ZPOpenURL : NSObject

@property (retain, nonatomic) NSString* genre;
@property (retain, nonatomic) NSString* metadata;
@property (retain, nonatomic) NSString* atitle;
@property (retain, nonatomic) NSString* jtitle;
@property (retain, nonatomic) NSString* stitle;
@property (retain, nonatomic) NSString* btitle;
@property (retain, nonatomic) NSString* volume;
@property (retain, nonatomic) NSString* issue;
@property (retain, nonatomic) NSString* inst;
@property (retain, nonatomic) NSString* assignee;
@property (retain, nonatomic) NSString* number;
@property (retain, nonatomic) NSString* invfirst;
@property (retain, nonatomic) NSString* invlast;
@property (retain, nonatomic) NSString* aufirst;
@property (retain, nonatomic) NSString* aulast;
@property (retain, nonatomic) NSString* aucorp;
@property (retain, nonatomic) NSString* pages;
@property (retain, nonatomic) NSString* spage;
@property (retain, nonatomic) NSString* epage;
@property (retain, nonatomic) NSString* tpages;
@property (retain, nonatomic) NSString* issn;
@property (retain, nonatomic) NSString* isbn;

-(id) initWithZoteroItem:(ZPZoteroItem*) item;
-(NSString*) version;

@end
