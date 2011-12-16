/*

Creates the DB used by ZotPad. Although zotero database was used as a
reference when designing the DB, this DB is consiredably more simple.

All data entities that have identifiers use key strings that are received
from the Zotero server. The only exception is libraries, that receive
integer ids from the server. 

TODO: Add indices and keys

*/

/*

Group is the same as library. My library is not stored, because it will
always exists. My library has id 1.

*/

CREATE TABLE IF NOT EXISTS groups ( 
    groupID INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS collections (
    collectionName TEXT NOT NULL,
    parentCollectionKey TEXT DEFAULT NULL,
    dateModified TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    libraryID INT,
    key TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS items (
    itemTypeID INT NOT NULL,
    dateModified TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    libraryID INT,
    year INT,
    authors TEXT,
    title TEXT,
    publishedIn TEXT,
    key TEXT NOT NULL,
    fullCitation TEXT NOT NULL,
    UNIQUE (libraryID, key)
);

CREATE TABLE IF NOT EXISTS collectionItems (
    collectionKey TEXT,
    itemKey TEXT,
    orderIndex INT DEFAULT 0,
    PRIMARY KEY (collectionKey, itemID),
    FOREIGN KEY (collectionKey) REFERENCES collections(collectionKey),
    FOREIGN KEY (itemID) REFERENCES items(itemID)
);

CREATE TABLE creators (
    itemKey TEXT NOT NULL,
    order INT NOT NULL,
    firstName TEXT,
    lastName TEXT,
    shortName TEXT,
    creatorType TEXT NOT NULL,
    fieldMode INT
);

CREATE TABLE fields (
    itemKey TEXT NOT NULL,
    fieldName TEXT NOT NULL,
    fieldValue TeXT NOT NULL
);
        
