Video encoder script for VRChat
===============================

Description
-----------
VRChat videoplayers in most world may load arbitary URLs, but they only support a narrow set of codecs and containers. This script was made to encode any `.mkv`-file thrown at it into a suitable format.

This way me and my friends are able to have movie nights in VRChat in **any** world with a videoplayer.

When this script is executed it gives points to different the differnt video, audio, and subtitle tracks from the input and then based on those points it later decides which of these track(s) should be in the final output.

Example
-------
Let's say the input `filename.mkv` has:

- 5.1 surround sound
- japanese audio
- many subtitles in different languages

In this example the script will:

- pick the japanese audio (personal preference)
- pick the english subtitles (personal preference)
- downmix the audio track to 2.0 (limitation: videoplayer only plays stereo channels)
- encode/burn the subtitle into the video (limitation: videoplayer doesn't display subtitles)

The final video will then be encoded to `filename.mp4`.

This file should then be placed on a public facing webserver.

The URL to `filename.mp4` may then be copied and pasted into a videoplayer in VRChat.

NOTES:
- keep in mind anyone who enters the world in VRChat will start to download the file, so make sure there's enough bandwidth.
- everyone needs to "allow untrusted URLs" in their VRChat settings.

Depends
-------

    apt install mkvtoolnix jshon ffmpeg

Usage
-----

    bin/main.sh file.mkv

