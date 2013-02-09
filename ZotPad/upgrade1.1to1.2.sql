BEGIN TRANSACTION;

UPDATE version SET version = 3;

ALTER TABLE collections ADD COLUMN locallyAdded INT DEFAULT 0;

/* Most tables need to be recreated because we need the etags from the server */

DROP TABLE items;

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

CREATE INDEX items_libraryID ON items (libraryID);

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


ALTER TABLE attachments ADD COLUMN note TEXT DEFAULT NULL,
ALTER TABLE attachments url TEXT DEFAULT NULL,
ALTER TABLE attachments accessDate TEXT DEFAULT NULL,
ALTER TABLE attachments locallyAdded INT DEFAULT 0,
ALTER TABLE attachments locallyModified INT DEFAULT 0,
ALTER TABLE attachments locallyDeleted INT DEFAULT 0

/* Force reloading all attachment metadata from the server */

UPDATE attachments SET cacheTimestamp = NULL;

DROP TABLE creators;

CREATE TABLE  IF NOT EXISTS creators (
    itemKey TEXT NOT NULL,
    authorOrder INT NOT NULL,
    firstName TEXT,
    lastName TEXT,
    name TEXT,
    creatorType TEXT NOT NULL,
    PRIMARY KEY (itemKey, authorOrder)
);

CREATE TABLE  IF NOT EXISTS  tags (
    itemKey TEXT NOT NULL,
    tagName TEXT NOT NULL,
    locallyAdded INT DEFAULT 0,
    locallyDeleted INT DEFAULT 0,
    PRIMARY KEY (itemKey, tagName)
);

COMMIT;