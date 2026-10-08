# Purpose: Validate image coding directories and scripts


#!/usr/bin/env bash
set -Eeuo pipefail

BASE="${DAEMEONAI_HOME:-${HOME}/daemeonai}/image-coding"

[[ -d "$BASE/images" ]]
[[ -d "$BASE/results" ]]
[[ -x "$BASE/analyze-image.sh" ]]
[[ -x "$BASE/scan-jpegs.sh" ]]

find "$BASE/images" -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) -print >/dev/null

bash -n "$BASE/analyze-image.sh"
bash -n "$BASE/scan-jpegs.sh"

echo "IMAGE_CODING_TEST=PASS"
