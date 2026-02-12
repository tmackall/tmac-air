#!/usr/bin/env bash
# Renames macOS screenshots from:
#   "Screenshot 2026-02-12 at 02.29.24.png" -> "scr-20260212-022924.png"
# Watches ~/Desktop for new Screenshot files.

DIR="$HOME/Desktop"

for f in "$DIR"/Screenshot\ *.png; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  # Extract: Screenshot YYYY-MM-DD at HH.MM.SS.png
  if [[ "$base" =~ ^Screenshot\ ([0-9]{4})-([0-9]{2})-([0-9]{2})\ at\ ([0-9]{2})\.([0-9]{2})\.([0-9]{2})\.png$ ]]; then
    new="scr-${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}-${BASH_REMATCH[4]}${BASH_REMATCH[5]}${BASH_REMATCH[6]}.png"
    mv "$f" "$DIR/$new"
  fi
done
