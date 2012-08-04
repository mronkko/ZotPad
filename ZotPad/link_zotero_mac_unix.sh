#!/bin/bash

#  link_zotero_mac_linux.sh
#  ZotPad
#
#  Created by Mikko Rönkkö on 7/11/12.
#  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.



# Locate profile directory. 


# Mac

if [ -e ~/Library/Application\ Support/Zotero/profiles.ini ]
then

echo "Found Mac Zotero Standalone profile"
PROFILEBASE=~/Library/Application\ Support/Zotero/

elif [ -e ~/Library/Application\ Support/Firefox/profiles.ini ]
then

echo "Found Mac Firefox profile"
PROFILEBASE=~/Library/Application\ Support/Firefox/

# Other unix

elif [ -e ~/.zotero/zotero/profiles.ini ]
then

echo "Found Linux/Unix Zotero Standalone profile"
PROFILEBASE=~/.zotero/zotero/

elif [ -e ~/.mozilla/firefox/profiles.ini ]
then

echo "Found Linux/Unix Firefox profile"
PROFILEBASE=~/.mozilla/firefox/


else

echo "Could not locate Firefox or Zotero Standalone profile"
exit 1

fi

# Parse the default profile, multiple profiles

DEFAULTPROFILE="$PROFILEBASE$(cat "$PROFILEBASE/profiles.ini" | grep -B 1 "Default=1" | head -n1 | sed 's/Path=//')"

# If not found, fall back to default profile
if [ "$DEFAULTPROFILE" == "" ]
then
    DEFAULTPROFILE="$PROFILEBASE$(cat "$PROFILEBASE/profiles.ini" | grep "Path=" | sed 's/Path=//')"
    echo "Found a single profile at $DEFAULTPROFILE"
else
    echo "Found multipler profiles, using the default at $DEFAULTPROFILE"
fi

# Parse preferences

if [ -e "$DEFAULTPROFILE/prefs.js" ]
then

    if [ "$(cat "$DEFAULTPROFILE/prefs.js" | grep 'user_pref("extensions.zotero.useDataDir", true);')" == "" ]
    then

        ZOTERODATADIR="$DEFAULTPROFILE/zotero"

    else

        ZOTERODATADIR=$(cat "$DEFAULTPROFILE/prefs.js" | grep "extensions.zotero.dataDir" | sed 's/user_pref(\"extensions.zotero.dataDir\", \"\(.*\)\");/\1/')

    fi

else

    echo "Could not read Zotero preferences"
    exit 1

fi

if [ -e "$ZOTERODATADIR" ]
then


CURRENTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Linking ZotPad App folder at $CURRENTDIR/storage to Zotero storage directory at $ZOTERODATADIR/storage"


ln -s "$ZOTERODATADIR/storage" "$CURRENTDIR/storage"

else

echo "Could not read Zotero data directory"
exit 1

fi

