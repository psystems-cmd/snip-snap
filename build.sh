#!/bin/bash
# Rebuilds the screen-ocr binary from source. Run after editing snip-ocr.swift.
set -euo pipefail
cd "$(dirname "$0")"
swiftc -O -o snip-ocr snip-ocr.swift
echo "built: $(pwd)/snip-ocr"
