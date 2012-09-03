BEGIN TRANSACTION;

DELETE FROM groups WHERE groupID = 1;

CREATE TABLE libraries ( 
    libraryID INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    cacheTimestamp TEXT DEFAULT NULL
);

INSERT INTO libraries SELECT * from groups;
DROP TABLE groups;




ALTER TABLE collections RENAME TO temp;

CREATE TABLE collections (
    title TEXT NOT NULL,
    parentKey TEXT DEFAULT NULL,
    cacheTimestamp TEXT DEFAULT NULL,
    libraryID INT,
    collectionKey TEXT PRIMARY KEY
);

INSERT INTO collections SELECT * FROM temp;
DROP TABLE temp;

CREATE INDEX collections_parentKey ON collections (parentKey);




ALTER TABLE items RENAME TO temp;

CREATE TABLE items (
    itemKey TEXT PRIMARY KEY,
    libraryID INT,
    title TEXT,
    year INT DEFAULT NULL,
    fullCitation TEXT NOT NULL,
    itemType TEXT NOT NULL,
    cacheTimestamp TEXT DEFAULT NULL,
    dateAdded TEXT DEFAULT NULL
);

INSERT INTO items SELECT key, libraryID, title, NULL, fullCitation, itemType, lastTimestamp, NULL FROM temp;
DROP TABLE temp;

CREATE INDEX items_libraryID ON items (libraryID);




ALTER TABLE notes RENAME TO temp;

CREATE TABLE notes (
    parentKey TEXT NOT NULL,
    itemKey TEXT PRIMARY KEY,
    cacheTimestamp TEXT NOT NULL
);

INSERT INTO notes SELECT * FROM temp;
DROP TABLE temp;

CREATE INDEX notes_parentKey ON notes (parentKey);



ALTER TABLE attachments RENAME TO temp;

CREATE TABLE attachments (
    parentKey TEXT NOT NULL,
    itemKey TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    cacheTimestamp TEXT NOT NULL,
    linkMode INT NOT NULL,
    filename TEXT DEFAULT NULL,
    contentType TEXT DEFAULT NULL,
    charset TEXT DEFAULT NULL,
    existsOnZoteroServer INT NOT NULL,
    attachmentSize INT DEFAULT NULL,
    lastViewed TIMESTAMP DEFAULT NULL,
    md5 TEXT DEFAULT NULL, 
    versionSource INT DEFAULT NULL,
    versionIdentifier_server TEXT DEFAULT NULL, 
    versionIdentifier_local TEXT DEFAULT NULL
);

INSERT INTO attachments SELECT parentKey, key, attachmentTitle, lastTimestamp, 0, attachmentTitle, attachmentType, NULL, attachmentURL IS NOT NULL, NULL, lastViewed, NULL, 1, NULL, NULL  FROM temp WHERE attachmentTitle IS NOT NULL;

DROP TABLE temp;

CREATE INDEX attachments_parentKey ON attachments (parentKey);




ALTER TABLE creators RENAME TO temp;

CREATE TABLE creators (
    itemKey TEXT NOT NULL,
    authorOrder INT NOT NULL,
    firstName TEXT,
    lastName TEXT,
    shortName TEXT,
    creatorType TEXT NOT NULL,
    PRIMARY KEY (itemKey, authorOrder)
);

INSERT INTO creators SELECT * FROM temp;
DROP TABLE temp;


INSERT INTO localization (language,type,key,value) SELECT "" AS language, "field" AS type, "itemType" AS key, "Item type" AS value
UNION SELECT "","field","dateModified","Date Modified"
UNION SELECT "","field","dateAdded","Date Added";

CREATE TABLE version ( 
    version INTEGER PRIMARY KEY
);

INSERT INTO version VALUES (2);

COMMIT;