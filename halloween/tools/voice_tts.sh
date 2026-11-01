#!/usr/bin/env bash
#
# The Halloween edition's phrases (halloween/voice/), from the Windows voice
# (SAPI, "Microsoft David") through WSL, then made spooky: the pitch 15%
# lower (and slower with it) and a short echo, as from a crypt. Not run
# by the build: the .wav files are in the repo. The names are the game's
# (sugarbyte: at the start, sweet / delicious: a long chain, crush: Sugar Crush).
#
#   halloween/tools/voice_tts.sh
set -euo pipefail
cd "$(dirname "$0")/.."
PS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
TMP="$(mktemp -d)"
W="$(wslpath -w "$TMP")"
"$PS" -NoProfile -Command "Add-Type -AssemblyName System.Speech;
  \$s = New-Object System.Speech.Synthesis.SpeechSynthesizer;
  \$s.SelectVoice('Microsoft David Desktop');
  foreach (\$p in @(@('sugarbyte','Happy Halloween!',0), @('sweet','Spooky!',-2),
                    @('crush','Sugar Crush!',0), @('delicious','Frightful!',0))) {
    \$s.Rate = \$p[2]; \$s.SetOutputToWaveFile('$W\\' + \$p[0] + '.wav'); \$s.Speak(\$p[1]) }
  \$s.Dispose()"
for f in sugarbyte sweet crush delicious; do
  ffmpeg -loglevel error -y -i "$TMP/$f.wav" \
    -af "silenceremove=start_periods=1:start_threshold=-40dB,aresample=16000,asetrate=16000*0.85,aresample=16000,aecho=0.8:0.7:60:0.2,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse" \
    -ac 1 -ar 16000 -c:a pcm_s16le "voice/$f.wav"
done
rm -rf "$TMP"
