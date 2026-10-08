# Purpose: Analyze all JPEG images in batch


#!/usr/bin/env bash
set -Eeuo pipefail

BASE="${DAEMEON_IMAGE_BASE:-${DAEMEONAI_HOME:-$HOME/daemeonai}/image-coding}"
LOG_DIR="$BASE/logs"
LOG_FILE="$LOG_DIR/scanner.log"

mkdir -p "$LOG_DIR"

find "$BASE/images" -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) -print0 |
  while IFS= read -r -d '' img; do
    if ! "$BASE/analyze-image.sh" "$img"; then
      printf 'FAILED: %s\n' "$img" >> "$LOG_FILE"
    fi
  done
