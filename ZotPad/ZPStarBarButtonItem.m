//
//  ZPStarBarButtonItem.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 10/27/12.
//
//

#import "ZPStarBarButtonItem.h"
#import "ZPUtils.h"

@interface ZPStarBarButtonItem ()
- (void) _setImageWithState:(BOOL) active;
@end

@implementation ZPStarBarButtonItem

-(id) init{
    self = [super init];
    
    self.image = [UIImage imageNamed:@"InactiveStar"];
    self.style = UIBarButtonItemStylePlain;
    self.target = self;
    self.action = @selector(toggleStar:);
    
    return self;
}

- (void) toggleStar:(id)sender{
    
    BOOL shouldAddToFavourites = self.image == [UIImage imageNamed:@"InactiveStar"];

    [self _setImageWithState:shouldAddToFavourites];
    
    // Write the favourites collection membership in the DB
    
    NSString* favouritesCollectionKey = [ZPDatabase collectionKeyForFavoritesCollectionInLibrary:_targetItem.libraryID];
    if(favouritesCollectionKey == NULL){
        [[[UIAlertView alloc] initWithTitle:@"Favourites collection created"
                                   message:[NSString stringWithFormat:@"Collection '%@' has been created in '%@'",
                                            [ZPPreferences favoritesCollectionTitle],
                                            [ZPZoteroLibrary libraryWithID:_targetItem.libraryID].title]
                                  delegate:nil
                         cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];

        favouritesCollectionKey = [ZPUtils randomString];
        [ZPDatabase w]
    }
}

- (void) _setImageWithState:(BOOL) active{
    if(active){
        self.image = [UIImage imageNamed:@"ActiveStar"];
    }
    else{
        self.image = [UIImage imageNamed:@"InactiveStar"];
    }
    
}

-(void) configureWithItem:(ZPZoteroItem*)item{
    _targetItem = item;
}

@end
