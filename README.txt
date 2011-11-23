	README FOR ZOTPAD

1 INTRODUCTION

ZotPad is a Zotero client for accessing Zotero database with iPad or iPhone. The sofware is focused on reading and annotating PDFs.  

ZotPad is currently looking for additional developers. If you are interested, please contact mikko.ronkko@aalto.fi. The source code is available under an open source license (GPL 3) and the plan is to release this as a free app in the App Store when it is ready. However, if someone who joins the project would prefer it to be a paid app, that is possible. 

The software will be available for testing when it is ready. When this will be depends on the amount of people joining the project.

2 USE AND FEATURES

This document describes the planned features for the first version. Not all described features are currenty implemented. The userinterface of the software consist of navigator showing the libraries and collections and item view showing either a list of items or details of one item.

This screenshot shows the software in iPad in landscape mode showing the navigator in the left and item view in the right
http://imageshack.us/photo/my-images/38/screenshot20111117at224.png/

The first time that a new user opens the app, it will open a web browser and present a loin page for Zotero. Entering a username and password will generate an authentication key that ZotPad will use to access the users database. The user password is not stored by ZotPad. The authentication key can be revoked by visiting https://www.zotero.org/settings/keys

After the user is authenticated, ZotPad connects the Zotero server and loads information about the user's library, the groups that the user has access to, and the collections that these contain. After the information about libraries and collections is loaded, it is displayed in the navigator. The item view is initially empty because no library or collection is selected.

When a user selects a library or a collection inside a library, ZotPad attempts to connect to Zotero server and request all items with the selected criteria, displays these, and starts to load the attachment files for these items in the background. (Support for offline use or use with slow internet connection will be implemented in later versions.) Once attachment files are available, they are shown as thumbnails. In the item view, the user has three options. Tapping on an attachment thumbnail will open an attachment as full screen with QuickLook. Tapping an item details button (not shown in screenshot) will change the item view from list to details of single items. This view can later be used to edit item metadata. A user can also tap an item in the list to select it and then click on export button in the navigation bar (not shown in screenshot) to open the item in any installed app that can open PDF files (e.g. iAnnotate, GoodReader, iBooks, Evernote) or as an attachment to a new email. ZotPad will monitor the opened PDFs and if these are changed, it will upload the changed file to Zotero server. (This feature is currently pending for Zotero to implement file upload support for third party applications.)

Support for tags, saved searches or editing items is currently not planned.


3 TECHNICAL INFORMATION

ZotPad uses the Master-Detail application template from XCode 4.2. It uses the Zotero public server read API and server write API. OAuthConsumer library is used for initial authentication.

ZotPad is not a standalone client in the same way as Zotero on a desktop computer, but an application that can be used to browse data on Zotero servers in online mode. However, because offline use is an important use case, ZotPad contains a cache of data present in the server. From the user interface, the cache is read only and there is no quarantee that it is consistent with the data on the Zotero server. Because of these two features, it is not necessary to sync the cache with the Zotero server in the same way as desktop Zotero does.

The communication with the Zotero server and the cache works in the following way: When a user selects a library or collection, or does a search or sorts the items, a new item view is configured. This starts by ZPDetailViewController requesting for an array of item keys in the view from ZPDataLayer. The data layer then decides if it is necessary to retrieve new data from the server. (In the current implementation server is always contacted) If the server is contacted, the item data are always written to the cache. Item details other than the keys in a view are then retrieved from the cache. This provides a single mechanism for providing data for the user interface regardless of the acutal source of the data (cache or server).

When contacting a server to present a new view, ZotPad first asks for 15 items. The response of this request is sufficient to generate the part of the item list that is shown to the user from a new view. Then ZotPad will queue retrieving rest fo the items in the view for background processing in Operation Queue. 

Item editing is not implemented currently, but is planned to work in the followign way: When an item is edited, the new values for the item fields are written using the server Write API. Then the item is purged from the cache, retieved again from the server, written back to cache, and updated in the user interface. This way there is only one path for data to follow, which helps to keep the user interface in a consistent state with the server.


Description of class files

Data objects:
ZPNavigatorNode - Stores data for one library or collection
ZPZoteroItem - Stores data for one Zotero item

User interface delegates:
ZPAppDelegate - The main app delegate
ZPAuthenticationDialog - Delegate for modal view that shows the Zotero login page when the user logs in the first time
ZPDetailViewController - Delegate for items list
ZPMasterViewController - Delegate for the navigator

Database connection:
ZPDataLayer - A singleton class that the user interface delegates use to get their data. All SQL queries are implemented in this class

Server:
ZPServerConnection - A singleton class for constructing queries and receiving responses from Zotero server. Uses OAuthConsumer library for authentication.
ZPItemRetrieveOperation - A subclass of NSOperation that retrieves data from Zoteor server in the background.
ZPServerResponseXMLParser - A parser delegate for NSXMLParser. Used to parse the responses from the Zotero server




