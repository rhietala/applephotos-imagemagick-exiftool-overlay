#!/usr/bin/env sh

# load configuration from .env file, verify that it is set up correctly

set -a
source .env
set +a

if [ -z "$INPUT_PATH" ] || [ -z "$OUTPUT_PATH" ]; then
    echo "environment is not set up correctly"
    exit 1
fi

image_date() {
    # get date from exif metadata
    # return in format dd.mm.yyyy without leading zeros in day and month

    local day=$(exiftool -DateTimeOriginal -d "%d" -s3 $1)
    local month=$(exiftool -DateTimeOriginal -d "%m" -s3 $1)
    local year=$(exiftool -DateTimeOriginal -d "%Y" -s3 $1)
    # remove leading zeros
    day=$(echo $day | sed 's/^0*//')
    month=$(echo $month | sed 's/^0*//')
    echo "$day.$month.$year"
}

image_description() {
    # get description from exif metadata
    # convert dots to linefeeds and add spaces around linefeeds

    local desc=$(exiftool -Description -s3 $1)
    echo $desc | sed 's/\./ \n /g'
}

is_title() {
    # check if argument array has "title" in it

    for i in "$@"; do
        if [ "$i" == "title" ]; then
            return 0
        fi
    done
    return 1
}

align_left() {
    # check if argument array has "left" in it

    for i in "$@"; do
        if [ "$i" == "left" ]; then
            return 0
        fi
    done
    return 1
}

album_name() {
    # get album name from keywords matching "album:*"
    # if no album is found, return "all"

    for i in "$@"; do
        if [[ $i == album:* ]]; then
            echo $i | cut -d':' -f2
            return
        fi
    done
    echo "all"
}

for filename in $INPUT_PATH/*; do
    echo "processing $(basename $filename)"

    date_str=$(image_date $filename)
    desc=$(image_description $filename)
    IFS=', ' read -r -a keywords <<< "$(exiftool -Keywords -s3 $filename)"

    # set gravity, pointsize and annotate_offset based on keywords

    if is_title "${keywords[@]}"; then
        gravity="south"
        pointsize="300"
        annotate_offset="+0+120"
        annotate_desc=$desc
    elif align_left "${keywords[@]}"; then
        gravity="southwest"
        pointsize="150"
        annotate_offset="+100+100"
        annotate_desc="$date_str \n $desc"
    else
        gravity="southeast"
        pointsize="150"
        annotate_offset="+100+100"
        annotate_desc="$date_str \n $desc"
    fi

    album=$(album_name "${keywords[@]}")

    magick $filename \
        -resize "3000x3000^" \
        -filter Lanczos \
        -define filter:blur=0.8 \
        -quality 95 \
        -sharpen 0x1.0 \
        -gravity $gravity \
        -font "Roboto-Slab-Regular" \
        -fill white -undercolor '#00000060' -pointsize $pointsize \
        -annotate $annotate_offset "\ $annotate_desc\ " \
        $OUTPUT_PATH/${album}-$(basename $filename)
done
