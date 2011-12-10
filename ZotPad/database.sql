CREATE TABLE IF NOT EXISTS groups ( 
    groupID INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS collections (
    collectionID INTEGER PRIMARY KEY AUTOINCREMENT,
    collectionName TEXT NOT NULL,
    parentCollectionID INT DEFAULT NULL,
    parentCollectionKey TEXT DEFAULT NULL,
    dateModified TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    libraryID INT,
    key TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS items (
    itemID INTEGER PRIMARY KEY AUTOINCREMENT,
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
    collectionID INT,
    itemID INT,
    orderIndex INT DEFAULT 0,
    PRIMARY KEY (collectionID, itemID),
    FOREIGN KEY (collectionID) REFERENCES collections(collectionID),
    FOREIGN KEY (itemID) REFERENCES items(itemID)
);