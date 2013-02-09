BEGIN TRANSACTION;

UPDATE version SET version = 3;


/* Most tables need to be recreated because we need the etags from the server */

UPDATE libraries SET libraryID = -1 WHERE libraryID = 1;

ALTER TABLE collections RENAME TO temp;

CREATE TABLE IF NOT EXISTS collections (
    title TEXT NOT NULL,
    parentKey TEXT DEFAULT NULL,
    cacheTimestamp TEXT DEFAULT NULL,
    libraryID INT,
    locallyAdded INT DEFAULT 0,
    collectionKey TEXT PRIMARY KEY
);

INSERT INTO collections SELECT title, parentCollectionKey, cacheTimestamp, libraryID, 0, collectionKey FROM temp;

DROP TABLE temp;

UPDATE collections SET libraryID = -1 WHERE libraryID = 1;

CREATE INDEX collections_parentKey ON collections (parentKey);

ALTER TABLE items RENAME TO temp;

CREATE TABLE IF NOT EXISTS items (
    itemKey TEXT PRIMARY KEY,
    libraryID INT,
    title TEXT,
    year INT DEFAULT NULL,
    itemType TEXT NOT NULL,
    etag TEXT DEFAULT NULL,
    cacheTimestamp TEXT DEFAULT NULL,
    dateAdded TEXT DEFAULT NULL,
    locallyAdded INT DEFAULT 0,
    locallyModified INT DEFAULT 0,
    locallyDeleted INT DEFAULT 0
);

INSERT INTO items SELECT itemKey, libraryID, title, year, itemType, NULL, NULL, dateAdded, 0, 0, 0 FROM temp;

DROP TABLE temp;

UPDATE items SET libraryID = -1 WHERE libraryID = 1;

CREATE INDEX items_libraryID ON items (libraryID);


ALTER TABLE collectionItems ADD COLUMN locallyAdded INT DEFAULT 0;
ALTER TABLE collectionItems ADD COLUMN locallyDeleted INT DEFAULT 0;


DROP TABLE notes;

CREATE TABLE IF NOT EXISTS notes (
    parentKey TEXT NOT NULL,
    itemKey TEXT PRIMARY KEY,
    note TEXT DEFAULT NULL,
    etag TEXT DEFAULT NULL,
    cacheTimestamp TEXT DEFAULT NULL,
    locallyAdded INT DEFAULT 0,
    locallyModified INT DEFAULT 0,
    locallyDeleted INT DEFAULT 0
);

CREATE INDEX notes_parentKey ON notes (parentKey);

ALTER TABLE attachments RENAME TO temp;

CREATE TABLE IF NOT EXISTS attachments (
    parentKey TEXT NOT NULL,
    itemKey TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    note TEXT DEFAULT NULL,
    cacheTimestamp TEXT NOT NULL,
    linkMode INT NOT NULL,
    filename TEXT DEFAULT NULL,
    url TEXT DEFAULT NULL,
    accessDate TEXT DEFAULT NULL,
    contentType TEXT DEFAULT NULL,
    charset TEXT DEFAULT NULL,
    existsOnZoteroServer INT NOT NULL,
    attachmentSize INT DEFAULT NULL,
    lastViewed TIMESTAMP DEFAULT NULL,
    md5 TEXT DEFAULT NULL,
    mtime INT DEFAULT 0,
    etag TEXT DEFAULT NULL,
    versionSource INT DEFAULT NULL,
    versionIdentifier_server TEXT DEFAULT NULL,
    versionIdentifier_local TEXT DEFAULT NULL,
    locallyAdded INT DEFAULT 0,
    locallyModified INT DEFAULT 0,
    locallyDeleted INT DEFAULT 0
);

INSERT INTO attachments SELECT parentItemKey, itemKey, title, "", "", linkMode, filename, NULL, NULL, contentType, charset, existsOnZoteroServer, attachmentSize, lastViewed, md5, 0, NULL, versionSource, versionIdentifier_server, versionIdentifier_local, 0, 0, 0 FROM temp;

DROP TABLE temp;

ALTER TABLE creators RENAME TO temp;

CREATE TABLE  IF NOT EXISTS creators (
    itemKey TEXT NOT NULL,
    authorOrder INT NOT NULL,
    firstName TEXT,
    lastName TEXT,
    name TEXT,
    creatorType TEXT NOT NULL,
    PRIMARY KEY (itemKey, authorOrder)
);

INSERT INTO creators SELECT itemKey, authorOrder, firstName, lastName, shortName, creatorType FROM temp;
DROP TABLE temp;

CREATE TABLE  IF NOT EXISTS  tags (
    itemKey TEXT NOT NULL,
    tagName TEXT NOT NULL,
    locallyAdded INT DEFAULT 0,
    locallyDeleted INT DEFAULT 0,
    PRIMARY KEY (itemKey, tagName)
);

COMMIT;