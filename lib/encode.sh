#!/bin/bash
encode_for_vrchat()
{
  local i="$1" ; shift
  local o

  o="${i%.*}.mp4"

  ffmpeg \
    -i "$i" \
    -c:v copy \
    -c:a aac \
    -b:a 192k \
    -ac 2 \
    -af "pan=stereo|FL < FL+1.414FC+0.5BL+0.5SL+0.25LFE+0.125BR|FR < FR+1.414FC+0.5BR+0.5SR+0.25LFE+0.125BL" \
    -f mp4 \
    "$o"
}

encode_subtitles()
{
  local i="$1" ; shift
  local s="$1" ; shift
  local o

  o="${i%.*}-sub.mp4"

  ffmpeg \
    -i "$i" \
    -c:a copy \
    -c:v libx264 -crf 20 \
    -vf "subtitles=$s" \
    -f mp4 \
    "$o"
}
