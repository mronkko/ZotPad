//
//  ZPStarBarButtonItem.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 10/27/12.
//
//

#import "ZPStarBarButtonItem.h"
#import "ZPUtils.h"
#import "ZPItemDataUploadManager.h"

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
    
    ZPZoteroItem* item = [ZPZoteroItem itemWithKey:_itemKey];
    
    NSString* favouritesCollectionKey = [ZPDatabase collectionKeyForFavoritesCollectionInLibrary:item.libraryID];

    if(favouritesCollectionKey == NULL){
        NSString* favoritesCollectionTitle = [ZPPreferences favoritesCollectionTitle];
        ZPZoteroLibrary* library = [ZPZoteroLibrary libraryWithID:item.libraryID];
        [[[UIAlertView alloc] initWithTitle:@"Favorites collection created"
                                    message:[NSString stringWithFormat:@"Collection '%@' has been created in '%@'",
                                             favoritesCollectionTitle,
                                             library.title]
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
        
        favouritesCollectionKey = [ZPUtils randomString];
        [ZPDatabase addCollectionWithTitle:favoritesCollectionTitle
                             collectionKey:favouritesCollectionKey
                                 toLibrary:library];
        
        //Notify that the collections have been updated
        [[NSNotificationCenter defaultCenter] postNotificationName:ZPNOTIFICATION_LIBRARY_WITH_COLLECTIONS_AVAILABLE object:library];
    }


    if(shouldAddToFavourites){
        [ZPDatabase addItemWithKeyLocally:_itemKey toCollection:favouritesCollectionKey];
    }
    else{
        [ZPDatabase removeItemWithKeyLocally:_itemKey fromCollection:favouritesCollectionKey];
    }

    [item setInFavourites:shouldAddToFavourites];
    
    // Update the changes to the server
    [ZPItemDataUploadManager uploadMetadata];
}

- (void) _setImageWithState:(BOOL) active{
    if(active){
        self.image = [UIImage imageNamed:@"ActiveStar"];
    }
    else{
        self.image = [UIImage imageNamed:@"InactiveStar"];
    }
    
}

-(void) configureWithItemKey:(NSString*)itemKey{
    _itemKey = itemKey;
    
    //If the favourites collection is defined, check if this item is included in the favourites
    [self _setImageWithState:[ZPZoteroItem itemWithKey:itemKey].isInFavourites];
}

@end
