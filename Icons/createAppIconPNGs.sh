#!/bin/bash
#
# Creates the app icon PNG files from the source SVG file and
# copies these into the right place
#

# iPhone application icon

for size in 57 72 114 144 512
do
	rsvg-convert --background-color=white --width=$size --height=$size --output=AppIcon${size}x$size.png ApplicationIcon.svg
	rsvg-convert --background-color=white --width=$size --height=$size --output=AppIcon${size}x$size-beta.png ApplicationIcon-beta.svg

done