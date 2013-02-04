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
    
    NSString* favouritesCollectionKey = [ZPDatabase collectionKeyForFavoritesCollectionInLibrary:_targetItem.libraryID];
    if(favouritesCollectionKey == NULL){
        NSString* favoritesCollectionTitle = [ZPPreferences favoritesCollectionTitle];
        ZPZoteroLibrary* library = [ZPZoteroLibrary libraryWithID:_targetItem.libraryID];
        [[[UIAlertView alloc] initWithTitle:@"Favourites collection created"
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
        [ZPDatabase addItemLocally:_targetItem toCollection:favouritesCollectionKey];
    }
    else{
        [ZPDatabase removeItemLocally:_targetItem fromCollection:favouritesCollectionKey];
    }

    [_targetItem setInFavourites:shouldAddToFavourites];
    
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

-(void) configureWithItem:(ZPZoteroItem*)item{
    _targetItem = item;
    
    //If the favourites collection is defined, check if this item is included in the favourites
    [self _setImageWithState:item.isInFavourites];
}

@end
