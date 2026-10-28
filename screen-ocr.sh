#!/bin/bash
# Raycast script command wrapper for screen-ocr.
# Add this directory in Raycast > Settings > Extensions > Scripts, then assign
# Cmd+Shift+ß to the "Screen OCR" entry that appears.
#
# @raycast.schemaVersion 1
# @raycast.title Screen OCR
# @raycast.mode silent
# @raycast.packageName Screen OCR
# @raycast.icon 🔤
# @raycast.description Select a screen region; its text goes to the clipboard.

exec "$HOME/Documents/claude-workspace/ops/screen-ocr/snip-ocr"
