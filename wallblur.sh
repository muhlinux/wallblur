#!/bin/bash

# <Constants>
cache_dir="$HOME/.cache/wallblur"
display_resolution="$(xdpyinfo | awk '/dimensions:/ {printf $2}')"
blur_delay=0
# </Constants>

# <Functions>
err() {
	echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

# Prevent multiple instances
if pidof -x "$(basename "$0")" -o $$ >/dev/null; then
    err 'Another instance of wallblur is already running.'
    exit 1
fi

gen_blurred_image () {
	notify-send "Building wallblur cache for "$base_filename""

	clean_cache

	wallpaper_resolution=$(identify -format "%wx%h" $wallpaper)

	err " Display resolution is: ""$display_resolution"""
	err " Wallpaper resolution is: $wallpaper_resolution"

	if [ "$wallpaper_resolution" != "$display_resolution" ]; then
		
		err "Scaling wallpaper to match resolution"
		convert $wallpaper -resize $display_resolution "$cache_dir"/"$filename"0."$extension"
		wallpaper="$cache_dir"/"$filename"0."$extension"
	fi

	blurred_wallaper=""$cache_dir"/"$filename""5"."$extension""
	convert -blur 0x8 $wallpaper $blurred_wallaper
	err " > Generating $(basename $blurred_wallaper)"

	notify-send "Finished building cache for "$base_filename""
}

do_blur () {
	blurred_wallaper=""$cache_dir"/"$filename""5"."$extension""
	feh --bg-fill "$blurred_wallaper" 
}

do_unblur () {
	feh --bg-fill "$wallpaper"
}

check_wallpaper_changed() {
	pywallpaper="$(grep wallpaper ~/.cache/wal/colors.sh | awk -F "=" '{print $2}')"
	temp_pre=${pywallpaper%\'} 
	temp_post="${temp_pre#\'}" 

	pywallpaper=${temp_post##*/}

	if [ "$pywallpaper" != "$base_filename" ]
	then
		err " Wallpaper changed. Going to update cache"

		wallpaper="$temp_post"
		base_filename=${wallpaper##*/}
		extension="${base_filename##*.}"
		filename="${base_filename%.*}"

		gen_blurred_image

		prev_state="reset"
	fi
}

clean_cache() {
	if [  "$(ls -A "$cache_dir")" ]; then
		err " * Cleaning existing cache"
		rm -r "$cache_dir"/*
	fi
}
# </Functions>

# Get the current wallpaper location from pywal cache
wallpaper="$(grep wallpaper ~/.cache/wal/colors.sh | awk -F "=" '{print $2}')"
temp_pre=${wallpaper%\'} 
wallpaper="${temp_pre#\'}" 
err "Current wallpaper: $wallpaper"

base_filename=${wallpaper##*/}
extension="${base_filename##*.}"
filename="${base_filename%.*}"


err "Blur delay       : $blur_delay"
err "Filename         : $base_filename"
err "Extension        : $extension"
#err $filename
err "Cache directory  : $cache_dir"

# Create a cache directory if it doesn't exist
if [ ! -d "$cache_dir" ]; then
	err "* Creating cache directory"
	mkdir -p "$cache_dir"
fi

blur_cache=""$cache_dir"/"$filename"0."$extension""

# Generate cached images if no cached images are found
if [ ! -f "$blur_cache" ]
then
	gen_blurred_image
fi

prev_state="reset"

while :; do

	check_wallpaper_changed

	current_workspace="$(xprop -root _NET_CURRENT_DESKTOP | awk '{print $3}')"
	#err $current_workspace
	if [[ -n "$current_workspace" ]]; then

		num_windows="$(echo "$(wmctrl -l)" | awk -F" " '{print $2}' | grep ^$current_workspace)"
	#	err $num_windows
		# If there are active windows
		if [ -n "$num_windows" ]; then
			if [ "$prev_state" != "blurred" ]; then
				err " ! Blurring"
				do_blur
			fi
			prev_state="blurred"
		    else #If there are no active windows
		    	if [ "$prev_state" != "unblurred" ]; then
		    		err " ! Un-blurring"
		    		do_unblur
		    	fi
		    	prev_state="unblurred"
		fi
	fi
	sleep "$blur_delay"
done
