#!/bin/bash
# Youtube to MP3 Bash Script

CPR='Jd Daniel :: Ehime-ken'
MOD=$(date +"%Y-%m-%d @ %H:%M:%S")
VER='Version 7.0.2 (OSX Maverick)'

# REF : https://github.com/ehime/Bash-Tools/blob/master/TOYS/y2m.sh
# REQ : http://developer.echonest.com/docs/v4/song.html

##  ##  ##  ##
##  ##  ##  ##

debug=''
video_title=''

## TODO: Clean up  optargs since its ugly and could be a lot better
## TODO: github.com/ehime/Bash-Tools/blob/master/GIT/git-backup.sh

## no long-opts supported except --help
while getopts 'v:d:t:i:-:' OPT; do
  case $OPT in
    t) video_title="${OPTARG}";;
    v) address="${OPTARG}";;
    d) dir=$OPTARG;;
    i) image=$OPTARG ; eval image=$image;;
    -) ## long option
    case $OPTARG in

      help) echo 'Long:  y2m -d {directory} -v {ex: http://www.youtube.com/watch?v=oHg5SJYRHA0‎}'
            echo 'Short: y2m {ex: http://www.youtube.com/watch?v=oHg5SJYRHA0‎}'
            exit
      ;;

      ## continues with argv[2] as address...
      debug) debug='--verbose --print-traffic --dump-pages'
             address="${2}"
      ;;

      flush) echo "[info] Flushing caches..."
             youtube-dl --rm-cache-dir
             exit
      ;;

    esac;;
  esac
done

cd /tmp

## TODO: implement for stripping / quoting
function ere_quote () {
    sed 's/[]\.|$(){}?+*^]/\\&/g' <<< "$*"
}

## if short order (y2m http://addy.com)
[ "x$address" == "x" ] && { address=$1 ; }
[ "x$dir" == "x" ]     && { dir="/Users/${USER}/Music/" ; }

## dir exists?
[ ! -d "${dir}" ]      && { echo "[error] Directory '${dir}' does not not exist..." ; exit 1 ; }

## set comments
COMMENTS="
CPR: $CPR
MOD: $MOD
VER: $VER
REF: $address
"

echo "[info] Using directory: ${dir}"

regex='v=(.*)'
[[ $address =~ $regex ]] && {

  ## argsmap
  video_id=${BASH_REMATCH[1]}
  video_id=$(echo $video_id | cut -d'&' -f1)

  filename=$(basename "$FILEPATH")
  extension="${filename##*.}"


  ## remove thumb if exists
  [ -f 'thumbnail.jpg' ] && {
    rm -f 'thumbnail.jpg'
  }


  ## get/set thumbnail for MP3
  if [[ "x$image" == "x" && ! -f "${image}" ]] ; then
    echo "[info] Downloading thumbnail"
    youtube-dl $debug --no-warnings --write-thumbnail $address -o thumbnail.jpg
  else
    echo "[info] Using ${image} as thumbail"
    cp -ir "${image}" thumbnail.jpg
  fi


  ## if you haven't defined a title....
  [ "x$video_title" == "x" ] && {
    video_title="$(youtube-dl $debug --no-warnings --get-title $address |sed s/://g)"
  }

  echo "[info] Title is: ${video_title}"


  # download the FLV stream
  youtube-dl $debug --no-warnings -o "$video_title" $address


  ## TODO: Add API lookup via Echonest
  artist="$(echo $video_title |awk -F '-' '{print$1}' |sed -e 's/\[.*//g' -e 's/  */ /g' -e 's/^ *\(.*\) *$/\1/')"
  title="$(echo $video_title  |awk -F '-' '{print$2}' |sed -e 's/\[.*//g' -e 's/  */ /g' -e 's/^ *\(.*\) *$/\1/')"
  video=$(ls |grep "${artist}") ## format independant, might need: head -n1, also hates ( ) [ ] etc

  echo "[info] Using Video: ${video}"


  ## REQ: FFMPEG proper installers via
  ## https://github.com/ehime/Bash-Tools/tree/master/STANDUP
  ffmpeg -i "$video"                   \
        -acodec libmp3lame             \
        -ab 320k                       \
        -ac 2                          \
        -vn                            \
        -y "$video_title".mp3


  ## add image with LAME since FFMPEG changes too much....
  lame --preset insane -V0 --id3v2-only --ignore-tag-errors \
       --ti 'thumbnail.jpg'                                 \
       --ta "${artist}"                                     \
       --tt "${title}"                                      \
       --tv "TPE2=${artist}"                                \
       --tc "${COMMENTS}"                                   \
       "$video_title".mp3 "${dir}/${video_title}.mp3"


  rm -f *.{webm,mp4,flv,mp3,jpg}
} || {
  echo "You fucked up..."
}
