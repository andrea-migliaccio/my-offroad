#!/usr/bin/env bash
# Re-downloads the third-party CC0/OFL packs into _downloads/ (one folder each).
# The files actually used are already copied into assets/; this is only needed
# to pick different sounds. See CREDITS.md.
set -e
cd "$(dirname "$0")/.."
mkdir -p _downloads/{font,sfx512,chiptunes,engine,impact}
touch _downloads/.gdignore
curl -sSL -o _downloads/font/PressStart2P-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/pressstart2p/PressStart2P-Regular.ttf"
curl -sSL -o _downloads/font/OFL.txt "https://github.com/google/fonts/raw/main/ofl/pressstart2p/OFL.txt"
curl -sSL -o _downloads/sfx512/pack.zip "https://opengameart.org/sites/default/files/The%20Essential%20Retro%20Video%20Game%20Sound%20Effects%20Collection%20%5B512%20sounds%5D.zip"
curl -sSL -o _downloads/chiptunes/pack.zip "https://opengameart.org/sites/default/files/5%20Action%20Chiptunes%20By%20Juhani%20Junkala.zip"
curl -sSL -o _downloads/engine/loop_0.wav "https://opengameart.org/sites/default/files/loop_0.wav"
curl -sSL -o _downloads/impact/pack.zip "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip"
for d in sfx512 chiptunes impact; do (cd _downloads/$d && unzip -q -o pack.zip -d x); done
echo "Downloaded into _downloads/"
