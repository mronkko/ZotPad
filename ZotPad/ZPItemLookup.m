//
//  ZPItemLookup.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 12/17/12.
//
//

#import "ZPItemLookup.h"

@interface ZPItemLookup(){
    UIActionSheet* _actionSheet;
    UIBarButtonItem* _sourceButton;
}

@end

@implementation ZPItemLookup

@synthesize item;

#pragma mark - Presenting the action menu

-(void) presentOptionsMenuFromBarButtonItem:(UIBarButtonItem*)button{
    
    
    _sourceButton = button;
    if(_actionSheet != NULL && _actionSheet.isVisible){
        [_actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
    }
    
    NSString* cancel;
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) cancel = @"Cancel";
    
    _actionSheet = [[UIActionSheet alloc]
                    initWithTitle:nil
                    delegate:self
                    cancelButtonTitle:cancel
                    destructiveButtonTitle:nil
                    otherButtonTitles:nil];
    
    [_actionSheet addButtonWithTitle:@"Zotero Online Library"];
    [_actionSheet addButtonWithTitle:@"CrossRef Lookup"];
    [_actionSheet addButtonWithTitle:@"Google Scholar Search"];
    [_actionSheet addButtonWithTitle:@"Pubget Lookup"];
    [_actionSheet addButtonWithTitle:@"Library Lookup"];
    [_actionSheet showFromBarButtonItem:button animated:YES];
    
    
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    /*
     [
     {
     "name": "CrossRef Lookup",
     "alias": "CrossRef",
     "icon": "file:///Users/mronkko/Documents/Zotero/locate/CrossRef%20Lookup.gif",
     "_urlTemplate": "http://crossref.org/openurl?{z:openURL}&pid=zter:zter321",
     "description": "CrossRef Search Engine",
     "hidden": false,
     "_urlParams": [],
     "_urlNamespaces": {
     "z": "http://www.zotero.org/namespaces/openSearch#",
     "": "http://a9.com/-/spec/opensearch/1.1/"
     },
     "_iconSourceURI": "http://crossref.org/favicon.ico"
     },
     {
     "name": "Google Scholar Search",
     "alias": "Google Scholar",
     "icon": "file:///Users/mronkko/Documents/Zotero/locate/Google%20Scholar%20Search.ico",
     "_urlTemplate": "http://scholar.google.com/scholar?as_q=&as_epq={z:title}&as_occt=title&as_sauthors={rft:aufirst?}+{rft:aulast?}&as_ylo={z:year?}&as_yhi={z:year?}&as_sdt=1.&as_sdtp=on&as_sdtf=&as_sdts=22&",
     "description": "Google Scholar Search",
     "hidden": false,
     "_urlParams": [],
     "_urlNamespaces": {
     "rft": "info:ofi/fmt:kev:mtx:journal",
     "z": "http://www.zotero.org/namespaces/openSearch#",
     "": "http://a9.com/-/spec/opensearch/1.1/"
     },
     "_iconSourceURI": "http://scholar.google.com/favicon.ico"
     },
     {
     "name": "Pubget Lookup",
     "alias": "Pubget",
     "icon": "file:///Users/mronkko/Documents/Zotero/locate/Pubget%20Lookup.ico",
     "_urlTemplate": "http://pubget.com/openurl?rft.title={rft:title}&rft.issue={rft:issue?}&rft.spage={rft:spage?}&rft.epage={rft:epage?}&rft.issn={rft:issn?}&rft.jtitle={rft:stitle?}&doi={z:DOI?}",
     "description": "Pubget Article Lookup",
     "hidden": false,
     "_urlParams": [],
     "_urlNamespaces": {
     "rft": "info:ofi/fmt:kev:mtx:journal",
     "z": "http://www.zotero.org/namespaces/openSearch#",
     "": "http://a9.com/-/spec/opensearch/1.1/"
     },
     "_iconSourceURI": "http://pubget.com/favicon.ico"
     }
     ]
     */
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) buttonIndex++;
    
    if(buttonIndex==1){
        //Cancel
    }
}

@end
