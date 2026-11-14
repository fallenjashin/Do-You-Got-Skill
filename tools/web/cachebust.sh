#!/usr/bin/env bash
# Give the exported game data a unique name so browsers never load a stale build.
# GitHub Pages lets browsers cache files ~10 min, and Godot always calls it index.pck.
# Usage: tools/web/cachebust.sh build/web <id>
set -euo pipefail
cd "$1"
PCK="game-$2.pck"
mv index.pck "$PCK"
sed -i "s/index\.pck/$PCK/g" index.html
# The loader uses config.mainPack, or "<executable>.pck" if it's missing, so set it.
sed -i "s/\"executable\":\"index\"/\"executable\":\"index\",\"mainPack\":\"$PCK\"/" index.html
grep -q "\"mainPack\":\"$PCK\"" index.html
! grep -q 'index\.pck' index.html
echo "game data: $PCK"
