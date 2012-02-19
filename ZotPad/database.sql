/*

Creates the DB used by ZotPad. Although zotero database was used as a
reference when designing the DB, this DB is consiredably more simple.

All data entities that have identifiers use key strings that are received
from the Zotero server. The only exception is libraries, that receive
integer ids from the server. 

*/

PRAGMA synchronous=OFF;

/*

Group is the same as library. My library is not stored, because it will
always exists.

*/

CREATE TABLE IF NOT EXISTS groups ( 
    groupID INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    cacheTimestamp TEXT DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS collections (
    title TEXT NOT NULL,
    parentCollectionKey TEXT DEFAULT NULL,
    cacheTimestamp TEXT DEFAULT NULL,
    libraryID INT,
    collectionKey TEXT PRIMARY KEY
);

CREATE INDEX collections_parentCollectionKey ON collections (parentCollectionKey);


CREATE TABLE IF NOT EXISTS items (
    itemKey TEXT PRIMARY KEY,
    itemType TEXT NOT NULL,
    libraryID INT,
    date INT,
    creator TEXT,
    title TEXT,
    publicationTitle TEXT,
    fullCitation TEXT NOT NULL,
    cacheTimestamp TEXT DEFAULT NULL
);

CREATE INDEX items_libraryID ON items (libraryID);

/*
 
 Notes and attachments are subclasses of item, so they have itemKey as primary key.

*/


CREATE TABLE IF NOT EXISTS notes (
    parentItemKey TEXT NOT NULL,
    itemKey TEXT PRIMARY KEY,
    cacheTimestamp TEXT NOT NULL
);

CREATE INDEX notes_parentItemKey ON notes (parentItemKey);


CREATE TABLE IF NOT EXISTS attachments (
    parentItemKey TEXT NOT NULL,
    itemKey TEXT PRIMARY KEY,
    cacheTimestamp TEXT NOT NULL,
    attachmentURL TEXT,
    attachmentType TEXT,
    attachmentTitle TEXT,
    attachmentLength TEXT,
    lastViewed TIMESTAMP DEFAULT NULL
);

CREATE INDEX attachments_parentItemKey ON attachments (parentItemKey);



CREATE TABLE IF NOT EXISTS collectionItems (
    collectionKey TEXT,
    itemKey TEXT,
    PRIMARY KEY (collectionKey, itemKey),
    FOREIGN KEY (collectionKey) REFERENCES collections(collectionKey),
    FOREIGN KEY (itemKey) REFERENCES items(itemKey)
);

/*    fieldMode INT  -  This is used by Zotero, but it is probably not needed by ZotPad. Leaving this comment here if storign field mode becomes relevant */

CREATE TABLE  IF NOT EXISTS creators (
    itemKey TEXT NOT NULL,
    "order" INT NOT NULL,
    firstName TEXT,
    lastName TEXT,
    shortName TEXT,
    creatorType TEXT NOT NULL,
    PRIMARY KEY (itemKey, "order")
);

CREATE TABLE  IF NOT EXISTS  fields (
    itemKey TEXT NOT NULL,
    fieldName TEXT NOT NULL,
    fieldValue TeXT NOT NULL,
    PRIMARY KEY (itemKey, fieldName)
);

CREATE TABLE IF NOT EXISTS localization (
    language TEXT NOT NULL,
    type TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    PRIMARY KEY (language,type,key)
);

INSERT INTO localization (language,type,key,value) SELECT "" AS languare, "itemType" AS type, "artwork" AS key, "Artwork" AS value
UNION SELECT "","itemType","audioRecording","Audio Recording"
UNION SELECT "","itemType","bill","Bill"
UNION SELECT "","itemType","blogPost","Blog Post"
UNION SELECT "","itemType","book","Book"
UNION SELECT "","itemType","bookSection","Book Section"
UNION SELECT "","itemType","case","Case"
UNION SELECT "","itemType","computerProgram","Computer Program"
UNION SELECT "","itemType","conferencePaper","Conference Paper"
UNION SELECT "","itemType","dictionaryEntry","Dictionary Entry"
UNION SELECT "","itemType","document","Document"
UNION SELECT "","itemType","email","E-mail"
UNION SELECT "","itemType","encyclopediaArticle","Encyclopedia Article"
UNION SELECT "","itemType","film","Film"
UNION SELECT "","itemType","forumPost","Forum Post"
UNION SELECT "","itemType","hearing","Hearing"
UNION SELECT "","itemType","instantMessage","Instant Message"
UNION SELECT "","itemType","interview","Interview"
UNION SELECT "","itemType","journalArticle","Journal Article"
UNION SELECT "","itemType","letter","Letter"
UNION SELECT "","itemType","magazineArticle","Magazine Article"
UNION SELECT "","itemType","manuscript","Manuscript"
UNION SELECT "","itemType","map","Map"
UNION SELECT "","itemType","newspaperArticle","Newspaper Article"
UNION SELECT "","itemType","note","Note"
UNION SELECT "","itemType","patent","Patent"
UNION SELECT "","itemType","podcast","Podcast"
UNION SELECT "","itemType","presentation","Presentation"
UNION SELECT "","itemType","radioBroadcast","Radio Broadcast"
UNION SELECT "","itemType","report","Report"
UNION SELECT "","itemType","statute","Statute"
UNION SELECT "","itemType","tvBroadcast","TV Broadcast"
UNION SELECT "","itemType","thesis","Thesis"
UNION SELECT "","itemType","videoRecording","Video Recording"
UNION SELECT "","itemType","webpage","Web Page"
UNION SELECT "","itemType","attachment","Attachment"
UNION SELECT "","field","numPages","# of Pages"
UNION SELECT "","field","numberOfVolumes","# of Volumes"
UNION SELECT "","field","abstractNote","Abstract"
UNION SELECT "","field","accessDate","Accessed"
UNION SELECT "","field","applicationNumber","Application Number"
UNION SELECT "","field","archive","Archive"
UNION SELECT "","field","artworkSize","Artwork Size"
UNION SELECT "","field","assignee","Assignee"
UNION SELECT "","field","billNumber","Bill Number"
UNION SELECT "","field","blogTitle","Blog Title"
UNION SELECT "","field","bookTitle","Book Title"
UNION SELECT "","field","callNumber","Call Number"
UNION SELECT "","field","caseName","Case Name"
UNION SELECT "","field","code","Code"
UNION SELECT "","field","codeNumber","Code Number"
UNION SELECT "","field","codePages","Code Pages"
UNION SELECT "","field","codeVolume","Code Volume"
UNION SELECT "","field","committee","Committee"
UNION SELECT "","field","company","Company"
UNION SELECT "","field","conferenceName","Conference Name"
UNION SELECT "","field","country","Country"
UNION SELECT "","field","court","Court"
UNION SELECT "","field","DOI","DOI"
UNION SELECT "","field","date","Date"
UNION SELECT "","field","dateDecided","Date Decided"
UNION SELECT "","field","dateEnacted","Date Enacted"
UNION SELECT "","field","dictionaryTitle","Dictionary Title"
UNION SELECT "","field","distributor","Distributor"
UNION SELECT "","field","docketNumber","Docket Number"
UNION SELECT "","field","documentNumber","Document Number"
UNION SELECT "","field","edition","Edition"
UNION SELECT "","field","encyclopediaTitle","Encyclopedia Title"
UNION SELECT "","field","episodeNumber","Episode Number"
UNION SELECT "","field","extra","Extra"
UNION SELECT "","field","audioFileType","File Type"
UNION SELECT "","field","filingDate","Filing Date"
UNION SELECT "","field","firstPage","First Page"
UNION SELECT "","field","audioRecordingFormat","Format"
UNION SELECT "","field","videoRecordingFormat","Format"
UNION SELECT "","field","forumTitle","Forum\/Listserv Title"
UNION SELECT "","field","genre","Genre"
UNION SELECT "","field","history","History"
UNION SELECT "","field","ISBN","ISBN"
UNION SELECT "","field","ISSN","ISSN"
UNION SELECT "","field","institution","Institution"
UNION SELECT "","field","issue","Issue"
UNION SELECT "","field","issueDate","Issue Date"
UNION SELECT "","field","issuingAuthority","Issuing Authority"
UNION SELECT "","field","journalAbbreviation","Journal Abbr"
UNION SELECT "","field","label","Label"
UNION SELECT "","field","language","Language"
UNION SELECT "","field","programmingLanguage","Language"
UNION SELECT "","field","legalStatus","Legal Status"
UNION SELECT "","field","legislativeBody","Legislative Body"
UNION SELECT "","field","libraryCatalog","Library Catalog"
UNION SELECT "","field","archiveLocation","Loc. in Archive"
UNION SELECT "","field","interviewMedium","Medium"
UNION SELECT "","field","artworkMedium","Medium"
UNION SELECT "","field","meetingName","Meeting Name"
UNION SELECT "","field","nameOfAct","Name of Act"
UNION SELECT "","field","network","Network"
UNION SELECT "","field","pages","Pages"
UNION SELECT "","field","patentNumber","Patent Number"
UNION SELECT "","field","place","Place"
UNION SELECT "","field","postType","Post Type"
UNION SELECT "","field","priorityNumbers","Priority Numbers"
UNION SELECT "","field","proceedingsTitle","Proceedings Title"
UNION SELECT "","field","programTitle","Program Title"
UNION SELECT "","field","publicLawNumber","Public Law Number"
UNION SELECT "","field","publicationTitle","Publication"
UNION SELECT "","field","publisher","Publisher"
UNION SELECT "","field","references","References"
UNION SELECT "","field","reportNumber","Report Number"
UNION SELECT "","field","reportType","Report Type"
UNION SELECT "","field","reporter","Reporter"
UNION SELECT "","field","reporterVolume","Reporter Volume"
UNION SELECT "","field","rights","Rights"
UNION SELECT "","field","runningTime","Running Time"
UNION SELECT "","field","scale","Scale"
UNION SELECT "","field","section","Section"
UNION SELECT "","field","series","Series"
UNION SELECT "","field","seriesNumber","Series Number"
UNION SELECT "","field","seriesText","Series Text"
UNION SELECT "","field","seriesTitle","Series Title"
UNION SELECT "","field","session","Session"
UNION SELECT "","field","shortTitle","Short Title"
UNION SELECT "","field","studio","Studio"
UNION SELECT "","field","subject","Subject"
UNION SELECT "","field","system","System"
UNION SELECT "","field","title","Title"
UNION SELECT "","field","thesisType","Type"
UNION SELECT "","field","mapType","Type"
UNION SELECT "","field","manuscriptType","Type"
UNION SELECT "","field","letterType","Type"
UNION SELECT "","field","presentationType","Type"
UNION SELECT "","field","url","URL"
UNION SELECT "","field","university","University"
UNION SELECT "","field","version","Version"
UNION SELECT "","field","volume","Volume"
UNION SELECT "","field","websiteTitle","Website Title"
UNION SELECT "","field","websiteType","Website Type"
UNION SELECT "","creatorType","artist","Artist"
UNION SELECT "","creatorType","attorneyAgent","Attorney\/Agent"
UNION SELECT "","creatorType","author","Author"
UNION SELECT "","creatorType","bookAuthor","Book Author"
UNION SELECT "","creatorType","cartographer","Cartographer"
UNION SELECT "","creatorType","castMember","Cast Member"
UNION SELECT "","creatorType","commenter","Commenter"
UNION SELECT "","creatorType","composer","Composer"
UNION SELECT "","creatorType","contributor","Contributor"
UNION SELECT "","creatorType","cosponsor","Cosponsor"
UNION SELECT "","creatorType","counsel","Counsel"
UNION SELECT "","creatorType","director","Director"
UNION SELECT "","creatorType","editor","Editor"
UNION SELECT "","creatorType","guest","Guest"
UNION SELECT "","creatorType","interviewee","Interview With"
UNION SELECT "","creatorType","interviewer","Interviewer"
UNION SELECT "","creatorType","inventor","Inventor"
UNION SELECT "","creatorType","performer","Performer"
UNION SELECT "","creatorType","podcaster","Podcaster"
UNION SELECT "","creatorType","presenter","Presenter"
UNION SELECT "","creatorType","producer","Producer"
UNION SELECT "","creatorType","programmer","Programmer"
UNION SELECT "","creatorType","recipient","Recipient"
UNION SELECT "","creatorType","reviewedAuthor","Reviewed Author"
UNION SELECT "","creatorType","scriptwriter","Scriptwriter"
UNION SELECT "","creatorType","seriesEditor","Series Editor"
UNION SELECT "","creatorType","sponsor","Sponsor"
UNION SELECT "","creatorType","translator","Translator"
UNION SELECT "","creatorType","wordsBy","Words By";


