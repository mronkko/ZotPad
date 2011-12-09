#!/bin/bash
#
# Creates the app icon PNG files from the source SVG file and
# copies these into the right place
#

# iPhone application icon
rsvg-convert --background-color=white --width=57 --height=57 --output=57x57.png ApplicationIcon.svg

# iPhone application icon (retina display)
rsvg-convert --background-color=white --width=114 --height=114  --output=114x114.png ApplicationIcon.svg

# iPad application icon
rsvg-convert --background-color=white --width=72 --height=72 --output=72x72.png ApplicationIcon.svg

# App store icon
rsvg-convert --background-color=white --width=512 --height=512 --output=512x512.png ApplicationIcon.svg
