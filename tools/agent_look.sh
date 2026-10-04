#!/bin/sh
# Zoom into part of a screenshot without the game running (a player leaning
# in to read a small icon): writes look.png next to it, x scale (default 3).
#   sh look.sh step_012.png <x> <y> <w> <h> [scale]
d="$(cd "$(dirname "$0")" && pwd)"
python3 - "$d/$1" "$2" "$3" "$4" "$5" "${6:-3}" "$d/look.png" <<'PY'
import sys
from PIL import Image
src, x, y, w, h, k, out = sys.argv[1], *map(int, sys.argv[2:7]), sys.argv[7]
Image.open(src).crop((x, y, x + w, y + h)).resize((w * k, h * k), Image.NEAREST).save(out)
print(out)
PY
