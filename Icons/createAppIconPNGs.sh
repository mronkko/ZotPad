#!/bin/bash
#
# Creates the app icon PNG files from the source SVG file and
# copies these into the right place
#

# iPhone application icon

for size in  16 57 64 72 114 128 144 512 1024
do
	
	echo "${size}x${size}"

	echo "Raw icons"
	
	rsvg-convert --background-color=white --width=$size --height=$size --output=AppIcon${size}x$size.png ApplicationIcon.svg
	rsvg-convert --background-color=white --width=$size --height=$size --output=AppIcon${size}x$size-beta.png ApplicationIcon-beta.svg

	#precomposed icons
	#Divide length by 6.4 to get the corner radius
	ratio=6.4
	corner="$(echo "$size/$ratio" | bc)"

	echo "Creating gloss for precomposed icons"

	/opt/local/bin/convert gloss-over.png -resize ${size}x$size temp1.png
	
	echo "Creating precomposed icon"
    /opt/local/bin/convert -draw "image Screen 0,0 0,0 'temp1.png'" \
    AppIcon${size}x$size-beta.png temp2.png

	
	/opt/local/bin/convert -size ${size}x$size xc:none -fill white -draw \
    "roundRectangle 0,0 $size,$size $corner,$corner" temp2.png \
    -compose SrcIn -composite AppIcon${size}x$size-beta-precomposed.png

	echo "Creating precomposed beta icon"

    /opt/local/bin/convert -draw "image Screen 0,0 0,0 'temp1.png'" \
    AppIcon${size}x$size.png temp2.png

	
	/opt/local/bin/convert -size ${size}x$size xc:none -fill white -draw \
    "roundRectangle 0,0 $size,$size $corner,$corner" temp2.png \
    -compose SrcIn -composite AppIcon${size}x$size-precomposed.png
    
    
done