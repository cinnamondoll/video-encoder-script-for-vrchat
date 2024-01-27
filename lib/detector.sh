#!/bin/bash
detector_1()
{
  # prints: track language type codec anything
  # example:
  #   0 eng Video mpeg4 ...
  #   1 eng Audio vorbis ...
  #   2 jpn Audio vorbis ...
  #   3 eng Subtitle subrip ...
  ffprobe "$1" 2>&1 | \
    sed -ne "s/.*Stream #0:\([0-9]\+\)(\([a-z]\+\)): \([^:]\+\): \([a-zA-Z0-9]\+\) \(.*\)$/\1 \2 \3 \4 \5/p"
}

detector_2()
{
  # prints: track type codec
  # example:
  #   0 video MPEG-4p2
  #   1 audio Vorbis
  #   2 audio Vorbis
  #   3 subtitles SubRip/SRT
  mkvmerge --identify "$1" \
    | sed -ne "s/Track ID \([0-9]\+\): \([a-z]\+\) (\(.*\))$/\1 \2 \3/p"
}

detector_3()
{
  # prints: type track codec language audio-channels track-name
  # example:
  #   video     0 MPEG-4p2   eng null null
  #   audio     1 Vorbis     eng 6    null
  #   audio     2 Vorbis     jpn 6    null
  #   subtitles 3 SubRip/SRT eng null Songs
  local object

  object="$(mkvmerge --identification-format json --identify "$1")"

  # workaround for numbers outside of json spec
  object="$(sed -e "s/\"uid\": \([0-9]\{10,\}\)/\"uid\": \"\1\"/" <<<"$object")"

  jshon -Q -C -0 \
    -e tracks -a \
    -e type -u -p \
    -e id -u -p \
    -e codec -u -p \
    -e properties -e language -u -p \
    -e audio_channels -u -p \
    -e track_name -u \
    <<<"$object" \
    | paste -z -s -d '|||||\n' 
  echo
}

detector_attachment()
{
  # prints: type track
  # example:
  #   1 application/x-truetype-font filename.ttf
  #   2 application/x-truetype-font sad.ttf
  #   ...
  local object

  object="$(mkvmerge --identification-format json --identify "$1")"

  # workaround for numbers outside of json spec
  object="$(sed -e "s/\"uid\": \([0-9]\{10,\}\)/\"uid\": \"\1\"/" <<<"$object")"

  jshon -Q -C -0 \
    -e attachments -a \
    -e id -u -p \
    -e content_type -u -p \
    -e file_name -u \
    <<<"$object" \
    | paste -z -s -d '||\n' 
  echo
}

detector_start_time()
{
  # prints: float
  # this is used to know the offset for blu-ray subtitles (HDMV PGS)
  # example: 41.041000
  ffprobe -v error -print_format default=nw=1:nk=1 -show_entries stream=start_time -i "$1"
}
