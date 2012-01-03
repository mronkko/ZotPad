/*

Creates the DB used by ZotPad. Although zotero database was used as a
reference when designing the DB, this DB is consiredably more simple.

All data entities that have identifiers use key strings that are received
from the Zotero server. The only exception is libraries, that receive
integer ids from the server. 

TODO: Add indices and keys
TODO: Create triggers 

*/

/*

Group is the same as library. My library is not stored, because it will
always exists. My library has id 1.

*/

CREATE TABLE IF NOT EXISTS groups ( 
    groupID INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    lastCompletedCacheTimestamp TEXT DEFAULT NULL
);

INSERT INTO groups (groupid, title) VALUES (1,"My Library");

CREATE TABLE IF NOT EXISTS collections (
    title TEXT NOT NULL,
    parentCollectionKey TEXT DEFAULT NULL,
    lastCompletedCacheTimestamp TEXT DEFAULT NULL,
    libraryID INT,
    key TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS items (
    itemType TEXT NOT NULL,
    dateModified TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    libraryID INT,
    year INT,
    authors TEXT,
    title TEXT,
    publishedIn TEXT,
    key TEXT NOT NULL,
    fullCitation TEXT NOT NULL,
    lastTimestamp TEXT DEFAULT NULL,
    UNIQUE (libraryID, key)
);

CREATE TABLE IF NOT EXISTS notes (
    parentItemKey TEXT NOT NULL,
    key TEXT NOT NULL,
    lastTimestamp TEXT NOT NULL,
    PRIMARY KEY (key)
);

CREATE TABLE IF NOT EXISTS attachments (
    parentItemKey TEXT NOT NULL,
    key TEXT NOT NULL,
    lastTimestamp TEXT NOT NULL,
    attachmentURL TEXT NOT NULL,
    attachmentType TEXT NOT NULL,
    attachmentTitle TEXT NOT NULL,
    attachmentLength TEXT NOT NULL,
    lastViewed TIMESTAMP DEFAULT NULL,
    PRIMARY KEY (key)
);

CREATE TABLE IF NOT EXISTS collectionItems (
    collectionKey TEXT,
    itemKey TEXT,
    PRIMARY KEY (collectionKey, itemKey),
    FOREIGN KEY (collectionKey) REFERENCES collections(collectionKey),
    FOREIGN KEY (itemKey) REFERENCES items(itemKey)
);

CREATE TABLE  IF NOT EXISTS creators (
    itemKey TEXT NOT NULL,
    "order" INT NOT NULL,
    firstName TEXT,
    lastName TEXT,
    shortName TEXT,
    creatorType TEXT NOT NULL,
    fieldMode INT
);

CREATE TABLE  IF NOT EXISTS  fields (
    itemKey TEXT NOT NULL,
    fieldName TEXT NOT NULL,
    fieldValue TeXT NOT NULL
);

CREATE TABLE  IF NOT EXISTS localization (
    language TEXT NOT NULL,
    type TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    PRIMARY KEY (language,type,key)
);
  
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","artwork","Artwork");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","audioRecording","Audio Recording");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","bill","Bill");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","blogPost","Blog Post");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","book","Book");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","bookSection","Book Section");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","case","Case");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","computerProgram","Computer Program");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","conferencePaper","Conference Paper");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","dictionaryEntry","Dictionary Entry");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","document","Document");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","email","E-mail");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","encyclopediaArticle","Encyclopedia Article");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","film","Film");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","forumPost","Forum Post");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","hearing","Hearing");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","instantMessage","Instant Message");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","interview","Interview");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","journalArticle","Journal Article");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","letter","Letter");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","magazineArticle","Magazine Article");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","manuscript","Manuscript");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","map","Map");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","newspaperArticle","Newspaper Article");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","note","Note");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","patent","Patent");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","podcast","Podcast");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","presentation","Presentation");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","radioBroadcast","Radio Broadcast");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","report","Report");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","statute","Statute");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","tvBroadcast","TV Broadcast");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","thesis","Thesis");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","videoRecording","Video Recording");
INSERT INTO localization (language,type,key,value) VALUES ("","itemType","webpage","Web Page");
INSERT INTO localization (language,type,key,value) VALUES ("","field","numPages","# of Pages");
INSERT INTO localization (language,type,key,value) VALUES ("","field","numberOfVolumes","# of Volumes");
INSERT INTO localization (language,type,key,value) VALUES ("","field","abstractNote","Abstract");
INSERT INTO localization (language,type,key,value) VALUES ("","field","accessDate","Accessed");
INSERT INTO localization (language,type,key,value) VALUES ("","field","applicationNumber","Application Number");
INSERT INTO localization (language,type,key,value) VALUES ("","field","archive","Archive");
INSERT INTO localization (language,type,key,value) VALUES ("","field","artworkSize","Artwork Size");
INSERT INTO localization (language,type,key,value) VALUES ("","field","assignee","Assignee");
INSERT INTO localization (language,type,key,value) VALUES ("","field","billNumber","Bill Number");
INSERT INTO localization (language,type,key,value) VALUES ("","field","blogTitle","Blog Title");
INSERT INTO localization (language,type,key,value) VALUES ("","field","bookTitle","Book Title");
INSERT INTO localization (language,type,key,value) VALUES ("","field","callNumber","Call Number");
INSERT INTO localization (language,type,key,value) VALUES ("","field","caseName","Case Name");
INSERT INTO localization (language,type,key,value) VALUES ("","field","code","Code");
INSERT INTO localization (language,type,key,value) VALUES ("","field","codeNumber","Code Number");
INSERT INTO localization (language,type,key,value) VALUES ("","field","codePages","Code Pages");
INSERT INTO localization (language,type,key,value) VALUES ("","field","codeVolume","Code Volume");
INSERT INTO localization (language,type,key,value) VALUES ("","field","committee","Committee");
INSERT INTO localization (language,type,key,value) VALUES ("","field","company","Company");
INSERT INTO localization (language,type,key,value) VALUES ("","field","conferenceName","Conference Name");
INSERT INTO localization (language,type,key,value) VALUES ("","field","country","Country");
INSERT INTO localization (language,type,key,value) VALUES ("","field","court","Court");
INSERT INTO localization (language,type,key,value) VALUES ("","field","DOI","DOI");
INSERT INTO localization (language,type,key,value) VALUES ("","field","date","Date");
INSERT INTO localization (language,type,key,value) VALUES ("","field","dateDecided","Date Decided");
INSERT INTO localization (language,type,key,value) VALUES ("","field","dateEnacted","Date Enacted");
INSERT INTO localization (language,type,key,value) VALUES ("","field","dictionaryTitle","Dictionary Title");
INSERT INTO localization (language,type,key,value) VALUES ("","field","distributor","Distributor");
INSERT INTO localization (language,type,key,value) VALUES ("","field","docketNumber","Docket Number");
INSERT INTO localization (language,type,key,value) VALUES ("","field","documentNumber","Document Number");
INSERT INTO localization (language,type,key,value) VALUES ("","field","edition","Edition");
INSERT INTO localization (language,type,key,value) VALUES ("","field","encyclopediaTitle","Encyclopedia Title");
INSERT INTO localization (language,type,key,value) VALUES ("","field","episodeNumber","Episode Number");
INSERT INTO localization (language,type,key,value) VALUES ("","field","extra","Extra");
INSERT INTO localization (language,type,key,value) VALUES ("","field","audioFileType","File Type");
INSERT INTO localization (language,type,key,value) VALUES ("","field","filingDate","Filing Date");
INSERT INTO localization (language,type,key,value) VALUES ("","field","firstPage","First Page");
INSERT INTO localization (language,type,key,value) VALUES ("","field","audioRecordingFormat","Format");
INSERT INTO localization (language,type,key,value) VALUES ("","field","videoRecordingFormat","Format");
INSERT INTO localization (language,type,key,value) VALUES ("","field","forumTitle","Forum\/Listserv Title");
INSERT INTO localization (language,type,key,value) VALUES ("","field","genre","Genre");
INSERT INTO localization (language,type,key,value) VALUES ("","field","history","History");
INSERT INTO localization (language,type,key,value) VALUES ("","field","ISBN","ISBN");
INSERT INTO localization (language,type,key,value) VALUES ("","field","ISSN","ISSN");
INSERT INTO localization (language,type,key,value) VALUES ("","field","institution","Institution");
INSERT INTO localization (language,type,key,value) VALUES ("","field","issue","Issue");
INSERT INTO localization (language,type,key,value) VALUES ("","field","issueDate","Issue Date");
INSERT INTO localization (language,type,key,value) VALUES ("","field","issuingAuthority","Issuing Authority");
INSERT INTO localization (language,type,key,value) VALUES ("","field","journalAbbreviation","Journal Abbr");
INSERT INTO localization (language,type,key,value) VALUES ("","field","label","Label");
INSERT INTO localization (language,type,key,value) VALUES ("","field","language","Language");
INSERT INTO localization (language,type,key,value) VALUES ("","field","programmingLanguage","Language");
INSERT INTO localization (language,type,key,value) VALUES ("","field","legalStatus","Legal Status");
INSERT INTO localization (language,type,key,value) VALUES ("","field","legislativeBody","Legislative Body");
INSERT INTO localization (language,type,key,value) VALUES ("","field","libraryCatalog","Library Catalog");
INSERT INTO localization (language,type,key,value) VALUES ("","field","archiveLocation","Loc. in Archive");
INSERT INTO localization (language,type,key,value) VALUES ("","field","interviewMedium","Medium");
INSERT INTO localization (language,type,key,value) VALUES ("","field","artworkMedium","Medium");
INSERT INTO localization (language,type,key,value) VALUES ("","field","meetingName","Meeting Name");
INSERT INTO localization (language,type,key,value) VALUES ("","field","nameOfAct","Name of Act");
INSERT INTO localization (language,type,key,value) VALUES ("","field","network","Network");
INSERT INTO localization (language,type,key,value) VALUES ("","field","pages","Pages");
INSERT INTO localization (language,type,key,value) VALUES ("","field","patentNumber","Patent Number");
INSERT INTO localization (language,type,key,value) VALUES ("","field","place","Place");
INSERT INTO localization (language,type,key,value) VALUES ("","field","postType","Post Type");
INSERT INTO localization (language,type,key,value) VALUES ("","field","priorityNumbers","Priority Numbers");
INSERT INTO localization (language,type,key,value) VALUES ("","field","proceedingsTitle","Proceedings Title");
INSERT INTO localization (language,type,key,value) VALUES ("","field","programTitle","Program Title");
INSERT INTO localization (language,type,key,value) VALUES ("","field","publicLawNumber","Public Law Number");
INSERT INTO localization (language,type,key,value) VALUES ("","field","publicationTitle","Publication");
INSERT INTO localization (language,type,key,value) VALUES ("","field","publisher","Publisher");
INSERT INTO localization (language,type,key,value) VALUES ("","field","references","References");
INSERT INTO localization (language,type,key,value) VALUES ("","field","reportNumber","Report Number");
INSERT INTO localization (language,type,key,value) VALUES ("","field","reportType","Report Type");
INSERT INTO localization (language,type,key,value) VALUES ("","field","reporter","Reporter");
INSERT INTO localization (language,type,key,value) VALUES ("","field","reporterVolume","Reporter Volume");
INSERT INTO localization (language,type,key,value) VALUES ("","field","rights","Rights");
INSERT INTO localization (language,type,key,value) VALUES ("","field","runningTime","Running Time");
INSERT INTO localization (language,type,key,value) VALUES ("","field","scale","Scale");
INSERT INTO localization (language,type,key,value) VALUES ("","field","section","Section");
INSERT INTO localization (language,type,key,value) VALUES ("","field","series","Series");
INSERT INTO localization (language,type,key,value) VALUES ("","field","seriesNumber","Series Number");
INSERT INTO localization (language,type,key,value) VALUES ("","field","seriesText","Series Text");
INSERT INTO localization (language,type,key,value) VALUES ("","field","seriesTitle","Series Title");
INSERT INTO localization (language,type,key,value) VALUES ("","field","session","Session");
INSERT INTO localization (language,type,key,value) VALUES ("","field","shortTitle","Short Title");
INSERT INTO localization (language,type,key,value) VALUES ("","field","studio","Studio");
INSERT INTO localization (language,type,key,value) VALUES ("","field","subject","Subject");
INSERT INTO localization (language,type,key,value) VALUES ("","field","system","System");
INSERT INTO localization (language,type,key,value) VALUES ("","field","title","Title");
INSERT INTO localization (language,type,key,value) VALUES ("","field","thesisType","Type");
INSERT INTO localization (language,type,key,value) VALUES ("","field","mapType","Type");
INSERT INTO localization (language,type,key,value) VALUES ("","field","manuscriptType","Type");
INSERT INTO localization (language,type,key,value) VALUES ("","field","letterType","Type");
INSERT INTO localization (language,type,key,value) VALUES ("","field","presentationType","Type");
INSERT INTO localization (language,type,key,value) VALUES ("","field","url","URL");
INSERT INTO localization (language,type,key,value) VALUES ("","field","university","University");
INSERT INTO localization (language,type,key,value) VALUES ("","field","version","Version");
INSERT INTO localization (language,type,key,value) VALUES ("","field","volume","Volume");
INSERT INTO localization (language,type,key,value) VALUES ("","field","websiteTitle","Website Title");
INSERT INTO localization (language,type,key,value) VALUES ("","field","websiteType","Website Type");
