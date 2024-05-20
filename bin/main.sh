#!/bin/bash
set -eo pipefail
PATH="$(dirname "$(readlink -f "$0")"):$PATH"
BASE="${BASH_SOURCE[0]%/*}"

. "$BASE/../lib/detector.sh"

help()
{
  echo "Usage: ${0##*/} file.mkv [external_subtitles.srt]"
  exit $1
}

error()
{
  echo "ERROR: $1" >&2
  exit 1
}

warning()
{
  echo "WARNING: $1" >&2
}

depend()
{
  until [ -z "$1" ] ; do
    which "$1" &>/dev/null || error "Missing: $1"
    shift
  done
  #command ffmpeg -V 2>&1 | grep -q -- "--enable-libass"
}

debug()
{
  mkvextract() { echo DEBUG: mkvextract "$@"; }
  ffmpeg()     { echo DEBUG: ffmpeg     "$@"; }
}

fullpath()
{
  readlink -f "$1"
}

points()
{
  # sets: "points_" vars
  local file="$1"

  points_video_track=()
  points_audio_track=()
  points_subti_track=()

  while IFS="|" read type track codec lang channels name ; do
    case "$type" in
      video)
        case "$lang" in
          jpn)
            let ++points_video_track[$track]
            let ++points_video_track[$track]
            let ++points_video_track[$track]
            ;;
          und)
            let ++points_video_track[$track]
            let ++points_video_track[$track]
            ;;
          eng)
            let ++points_video_track[$track]
            ;;
          *)
            warning "Unknown video lang: $lang"
            ;;
        esac
        ;;
      audio)
        case "$lang" in
          jpn)
            let ++points_audio_track[$track]
            let ++points_audio_track[$track]
            let ++points_audio_track[$track]
            ;;
          und)
            let ++points_audio_track[$track]
            let ++points_audio_track[$track]
            ;;
          eng)
            let ++points_audio_track[$track]
            ;;
          *)
            warning "Unknown audio lang: $lang"
            ;;
        esac

        case "$channels" in
          6)
            let ++points_audio_track[$track]
            ;;
        esac
        ;;
      subtitles)
        case "$lang" in
          eng)
            let ++points_subti_track[$track]
            let ++points_subti_track[$track]
            ;;
          und)
            let ++points_subti_track[$track]
            ;;
          *)
            warning "Unknown subtitle lang: $lang"
            ;;
        esac

        case "$codec" in
          SubStationAlpha)
            let ++points_subti_track[$track]
            let ++points_subti_track[$track]
            let ++points_subti_track[$track]
            ;;
          HDMV\ PGS)
            let ++points_subti_track[$track]
            let ++points_subti_track[$track]
            ;;
          SubRip/SRT)
            let ++points_subti_track[$track]
            ;;
          *)
            warning "Unknown subtitle codec: $codec"
            ;;
        esac

        case "$name" in
          *[Ff]ull*)
            let ++points_subti_track[$track]
            ;;
        esac
        ;;
      *)
        warning "Unknown type: $type"
        ;;
    esac
  done < <(detector_3 "$file")
}

picker()
{
  # need: "points_" vars
  # sets: "picker_" vars
  local file="$1"

  picker_audio_track=
  picker_audio_points=
  picker_audio_lang=

  while IFS="|" read type track codec lang channels name ; do
    case "$type" in
      video)
        [ "${points_video_track[$track]:-0}" -ne 0 ] || continue
        [ "${points_video_track[$track]:-0}" -gt "${picker_video_points:-0}" ] || continue
        picker_video_track="$track"
        picker_video_points="${points_video_track[$track]}"
        ;;
      audio)
        [ "${points_audio_track[$track]:-0}" -ne 0 ] || continue
        [ "${points_audio_track[$track]:-0}" -gt "${picker_audio_points:-0}" ] || continue
        picker_audio_track="$track"
        picker_audio_points="${points_audio_track[$track]}"
        picker_audio_lang="$lang"
        ;;
      subtitles)
        [ "${points_subti_track[$track]:-0}" -ne 0 ] || continue
        [ "${points_subti_track[$track]:-0}" -gt "${picker_subti_points:-0}" ] || continue
        picker_subti_track="$track"
        picker_subti_points="${points_subti_track[$track]}"
        ;;
    esac
  done < <(detector_3 "$file")
}

picker_attachment()
{
  # sets: "picker_attachment_" vars
  local file="$1"

  picker_attachment_tracks=()

  while IFS="|" read track type filename ; do
    case "$type" in
      application/x-truetype-font|application/vnd.ms-opentype)
        picker_attachment_tracks+=("$track")
        ;;
      *font*|*type*)
        warning "Picked attachment track $track lazily: $type"
        picker_attachment_tracks+=("$track")
        ;;
    esac
  done < <(detector_attachment "$file")
}

encoder_opts()
{
  # need: "picker_" vars
  # sets: "do_" vars
  local file="$1"

  do_video_encode=false
  do_audio_encode=false
  do_audio_downmix=false
  do_subti_srt=false
  do_subti_ass=false
  do_subti_sup=false
  do_subti_attachment=false

  while IFS="|" read type track codec lang channels name ; do
    case "$type" in
      video)
        [ "$track" -eq "$picker_video_track" ] || continue
        case "$codec" in
          MPEG-4p*/AVC/h.264|MPEG-4p*)
            do_video_encode=false
            ;;
          *h.265)
            do_video_encode=true
            ;;
          *)
            warning "Unknown video codec: $codec"
            ;;
        esac
        ;;
      audio)
        [ "$track" -eq "$picker_audio_track" ] || continue
        case "$channels" in
          6)
            do_audio_downmix=true
            ;;
          2)
            do_audio_downmix=false
            ;;
          *)
            warning "Unknown audio channels: $channels"
            ;;
        esac

        case "$codec" in
          AAC)
            do_audio_encode=false
            ;;
          Vorbis|DTS|AC-3|FLAC)
            do_audio_encode=true
            ;;
          *)
            # assume we should encode
            do_audio_encode=true
            warning "Unknown audio codec: $codec"
            ;;
        esac
        ;;
      subtitles)
        [ "$track" -eq "$picker_subti_track" ] || continue
        case "$codec" in
          SubStationAlpha)
            do_subti_ass=true
            ;;
          SubRip/SRT)
            do_subti_srt=true
            ;;
          HDMV\ PGS)
            do_subti_sup=true
            ;;
          *)
            warning "Unknown subtitle codec: $codec"
            ;;
        esac

        case "$picker_audio_lang" in
          jpn|und)
            do_video_encode=true
            ;;
          *)
            [ "$picker_audio_lang" == "eng" ] || do_video_encode=true
            ;;
        esac
        ;;
    esac
  done < <(detector_3 "$file")

  if [ "${#picker_attachment_tracks[@]}" -ne 0 ] ; then
    do_subti_attachment=true
  fi
}

extract_tracks()
{
  # need: "picker_" vars
  local file="$1"
  local o=()

  o+=("tracks")
  o+=("$picker_video_track:video")
  o+=("$picker_audio_track:audio")

  [ -z "$picker_subti_track" ] || o+=("$picker_subti_track:subti")

  mkvextract "$file" "${o[@]}"

  if [ "${#picker_attachment_tracks[@]}" -ne 0 ] ; then
    o=("attachments")
    for i in "${picker_attachment_tracks[@]}" ; do
      o+=("$i")
    done
    mkdir attachment
    cd attachment
    mkvextract "$file" "${o[@]}"
    cd -
  fi
}

encode()
{
  # needs: "do_" vars
  local o

  o+=(-hide_banner)

  # write log to: program-YYYYMMDD-HHMMSS.log
  o+=(-report)

  # ffmpeg inputs
  o+=(-i) ; o+=(video) # stream 0
  o+=(-i) ; o+=(audio) # stream 1

  if $do_subti_sup ; then
    # draw picture-based subtitles ontop of video stream 1
    o+=(-itsoffset)
    o+=("$(detector_start_time subti)")
    o+=(-i)
    o+=(subti)
    o+=(-filter_complex)
    o+=("[0:v][2:s]overlay[v]")
    o+=(-map)
    o+=("[v]")
    # fix for missing audio stream
    o+=(-map)
    o+=("1:a:0")
  fi

  o+=(-c:v)
  if $do_video_encode ; then
    o+=(libx264) ; o+=(-crf) ; o+=(20)
    if $do_subti_ass || $do_subti_srt ; then
      o+=(-vf)
      if $do_subti_ass ; then
        # draw advanced subtitles ontop w/ or w/o fonts if they were embedded
        $do_subti_attachment \
          && o+=("ass=subti:fontsdir=attachment") \
          || o+=("ass=subti")
      else
        # draw plain text srt subtitles ontop
        o+=("subtitles=subti")
      fi
    fi
  else
    # skip subtitles and keep original stream
    o+=(copy)
  fi

  # audio
  o+=(-c:a)
  if $do_audio_encode || $do_audio_downmix ; then
    o+=(aac) ; o+=(-b:a) ; o+=(192k)
    if $do_audio_downmix ; then
      o+=(-ac) ; o+=(2) ; o+=(-af)
      o+=("pan=stereo|FL < FL+1.414FC+0.5BL+0.5SL+0.25LFE+0.125BR|FR < FR+1.414FC+0.5BR+0.5SR+0.25LFE+0.125BL")
    fi
  else
    o+=(copy)
  fi

  # recommended options for non-fragmented output
  o+=(-movflags)
  o+=(+faststart)

  # recommended options for fragmented output
  #o+=(-movflags)
  #o+=(+empty_moov+separate_moof)

  # output
  o+=(-f) ; o+=(mp4) ; o+=(output.mp4)

  ffmpeg "${o[@]}"
}

parse_file()
{
  local file="$1"

  # give each track points
  points "$file"

  # pick the video, audio, and subtitle track with most points
  picker "$file"

  # pick the attachments track such as fonts
  picker_attachment "$file"

  # find out encoding options for the tracks
  encoder_opts "$file"

  echo
  detector_3 "$file" | column -t -s "|" || true
  echo

  echo "picker_video_track=$picker_video_track (points: $picker_video_points)"
  echo "picker_audio_track=$picker_audio_track (points: $picker_audio_points)"
  echo "picker_subti_track=$picker_subti_track (points: $picker_subti_points)"
  echo
  echo "do_video_encode=$do_video_encode"
  echo "do_audio_encode=$do_audio_encode"
  echo "do_audio_downmix=$do_audio_downmix"
  echo "do_subti_srt=$do_subti_srt"
  echo "do_subti_ass=$do_subti_ass"
  echo "do_subti_sup=$do_subti_sup"
  echo "do_subti_attachment=$do_subti_attachment"
  echo

  # working directory
  work="$(mktemp --directory work-XXX)"
  work="$(readlink -f "$work")"
  cd "$work"
  echo "Working directory switched to: $work"

  # extract tracks
  extract_tracks "$file"

  # overrides
  if [ -n "$external_srt" ] ; then
    do_video_encode=true
    do_subti_srt=true
    do_subti_ass=false
    do_subti_sup=false
    cp "$external_srt" subti
  fi

  # encode
  encode

  # exit directory
  cd -

  # move the output.mp4 to input.mp4
  mv "$work/output.mp4" "${file%.*}.mp4"

  # clean up
  echo rm -r -- "$work"
}

main()
{
  local file

  # for security reasons
  [ $UID -ne 0 ] || error "Don't run this script as root"

  # error on missing depends
  depend mkvmerge mkvextract jshon ffmpeg

  debug
  unset -f mkvextract
  unset -f ffmpeg

  # parse paramenters
  [ $# -ne 0 ] || help 1
  until [ -z "$1" ] ; do
    case "$1" in
      -h|--help)
        help
        ;;
      *.srt)
        external_srt="$(fullpath "$1")"
        ;;
      *.mkv)
        [ -f "$1" ] || help 1
        file="$(fullpath "$1")"
        ;;
      *)
        help 1
        ;;
    esac
    shift
  done

  parse_file "$file"
}

main "$@"
