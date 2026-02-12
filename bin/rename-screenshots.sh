#!/usr/bin/env bash
# Renames macOS screenshots and screen recordings:
#   "Screenshot 2026-02-12 at 02.29.24.png"       -> "scr-20260212-022924.png"
#   "Screen Recording 2026-02-12 at 02.29.24.mov" -> "rec-20260212-022924.mov"
# Triggered by launchd when ~/Desktop changes.

DIR="$HOME/Desktop"

for f in "$DIR"/Screenshot\ *.png; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  if [[ "$base" =~ ^Screenshot\ ([0-9]{4})-([0-9]{2})-([0-9]{2})\ at\ ([0-9]{2})\.([0-9]{2})\.([0-9]{2})\.png$ ]]; then
    new="scr-${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}-${BASH_REMATCH[4]}${BASH_REMATCH[5]}${BASH_REMATCH[6]}.png"
    mv "$f" "$DIR/$new"
  fi
done

for f in "$DIR"/Screen\ Recording\ *.mov; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  if [[ "$base" =~ ^Screen\ Recording\ ([0-9]{4})-([0-9]{2})-([0-9]{2})\ at\ ([0-9]{2})\.([0-9]{2})\.([0-9]{2})\.mov$ ]]; then
    new="rec-${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}-${BASH_REMATCH[4]}${BASH_REMATCH[5]}${BASH_REMATCH[6]}.mov"
    mv "$f" "$DIR/$new"
  fi
done
