#!/usr/bin/env bash
# Exports the Product Hunt images and the site's social/app icons from
# docs/designs/preview/landing-page-preview.html with headless Chrome.
# Re-run after the preview's mockups are swapped for real screenshots.
#
#   bash docs/product-hunt/export.sh
#
# Writes:
#   docs/product-hunt/gallery-1.png ... gallery-6.png  (1270 x 760)
#   docs/product-hunt/thumbnail.png                    (240 x 240)
#   website/assets/img/og.png                          (1200 x 630, link previews)
#   website/assets/img/apple-touch-icon.png            (180 x 180)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PREVIEW_DIR="$ROOT/docs/designs/preview"
OUT="$ROOT/docs/product-hunt"
IMG="$ROOT/website/assets/img"
CHROME="${CHROME:-/c/Program Files/Google/Chrome/Application/chrome.exe}"
PROFILE="$(mktemp -d)"
TMP="$PREVIEW_DIR/_export.html"   # must sit next to the preview so its relative font paths resolve
trap 'rm -rf "$PROFILE" "$TMP"' EXIT

to_url() { # file:/// URL for a path, on Git Bash or Unix
  local p; p="$(cd "$(dirname "$1")" && pwd -W 2>/dev/null || pwd)/$(basename "$1")"
  echo "file:///${p#/}"
}

shoot() { # $1 extra CSS, $2 WxH, $3 output file
  sed -e 's|<html lang="en">|<html lang="en" data-theme="light">|' \
      -e "s|</head>|<style>$1</style></head>|" \
      "$PREVIEW_DIR/landing-page-preview.html" > "$TMP"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --user-data-dir="$PROFILE" \
    --window-size="$2" --virtual-time-budget=3000 --screenshot="$3" "$(to_url "$TMP")" >/dev/null 2>&1
  echo "wrote $3"
}

HIDE='.pv,.bar,main,#ph,.kit .wrap > :not(.gallery):not(.kgrid){display:none!important} body{margin:0;overflow:hidden}'
SLIDE='.sbox{position:fixed!important;left:0;top:0;width:1270px!important;border:0!important;z-index:99} .slide-wrap figcaption{display:none!important}'

for n in 1 2 3 4 5 6; do
  shoot "$HIDE .gallery figure:not(:nth-child($n)){display:none!important} $SLIDE" 1270,760 "$OUT/gallery-$n.png"
done

shoot "$HIDE .gallery figure:not(:nth-child(1)){display:none!important} $SLIDE .kgrid{display:none!important} .sbox{zoom:.829;margin-left:88.7px} body{background:#FDF0A6}" 1200,630 "$IMG/og.png"

shoot "$HIDE .gallery{display:none!important} .t240{position:fixed!important;left:0;top:0;border:0!important;z-index:99}" 240,240 "$OUT/thumbnail.png"

shoot "$HIDE .gallery{display:none!important} .t240{position:fixed!important;left:0;top:0;border:0!important;z-index:99;zoom:.75} .t240 .chip{display:none}" 180,180 "$IMG/apple-touch-icon.png"
