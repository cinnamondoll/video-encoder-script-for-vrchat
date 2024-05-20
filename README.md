Video encoder script for VRChat
===============================

Description
-----------
VRChat videoplayers in most worlds may load arbitary URLs, but they only support a narrow set of codecs and containers. This script was made to encode any `.mkv`-file thrown at it into a suitable format.

This way me and my friends are able to have movie nights in VRChat in **any** world with a videoplayer.

When this script is executed it scores different video, audio, and subtitle tracks from the input file and then based on the score it decides which of these track(s) should be in the final output file.

Example
-------
Let's say the input `filename.mkv` has:

- 5.1 surround sound
- japanese audio
- many subtitles in different languages

In this example the script will:

- pick the japanese audio
- pick the english subtitles
- downmix the audio track to 2.0
- encode/burn the subtitle into the video

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

