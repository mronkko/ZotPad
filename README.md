README for ZotPad
================================================================================

ZotPad is a Zotero client for accessing Zotero database with iPad or iPhone.
The sofware is focused on reading and annotating PDF as well as note taking and
tagging.

ZotPad is currently looking for additional developers. If you are interested,
please contact developers@zotpad.com. The source code is available under an open
source license (GPL 3) and the software is available in the App Store for a
small fee.

The project has a UserVoice page for feature requests. Please use the issue
tracker only for bugs, and request features here instead

http://zotpad.uservoice.com

More information can be found on the website 

http://www.zotpad.com

Checking out and compiling the code
================================================================================

1) Prerequisites
--------------------------------------------------------------------------------

Some of the features of ZotPad require closed source software or authentication
keys that cannot be distributed through GitHub, but need to be obtained
separately. ZotPad project contains three products ZotPad, ZotPad beta, and
ZotPad iAnnotate. The ZotPad beta is the only product that can be compiled
from a fresh checkout without creating authentication keys or installing
third party software. The keys are defined in the file ZotPad/ZPSecrets.h.

### Zotero OAuth keys

The public repository includes the keys for ZotPad beta. New keys can be created
at http://www.zotero.org/support/dev/server_api/oauth.

### Dropbox OAuth keys

The public repository includes the keys for ZotPad beta. New keys can be created
at https://www.dropbox.com/developers/apps.

### UserVoice OAuth keys

The public repository does not include any keys for UserVoice. UserVoice is used
for user support and testing of the official builds and is of very little use
for third party builds. All versions of ZotPad can be compiled without UserVoice
key. Attempting to use the in-app support in a build that does not contain a key
results in a harmless error message explaining that UserVoice is not available
in that build.

### TestFlight key

The public repository does not include any keys for TestFlight. TestFlight is
used for testing of the official builds and is of very little use for third
party builds. All versions of ZotPad can be compiled without TestFlight key.

### iAnnotate library

ZotPad iAnnotate requires a demo version of iAnnotate library. This can be
obtained at http://www.branchfire.com/download/demo/.

2) Checking out the project
--------------------------------------------------------------------------------

ZotPad can be cloned with the following command

    git clone --recursive  https://github.com/mronkko/ZotPad.git .

Or if you are using ssh key based authentication, use this command instead

    git clone --recursive git@github.com:mronkko/ZotPad.git .

ZotPad has dependencies that have their own dependencies that are not pulled automatically
these are configured with the following commands

    cd DTCoreText
    git submodule init
    git submodule update

Finally, the ZPSecrets file needs to be untracked so that any keys that you might add will
not be shared with the world.

    git update-index --assume-unchanged ZotPad/ZPSecrets.h



