# Purpose: Send JPEG to model for analysis


#!/usr/bin/env bash

# DAEMEONAI CENTRAL GEMINI ENV
if [ -r "/data/data/com.termux/files/home/daemeonai/lib/central-ai-env.sh" ]; then . "/data/data/com.termux/files/home/daemeonai/lib/central-ai-env.sh"; fi
. "${DAEMEONAI_HOME:-$HOME/daemeonai}/lib/central-openai-env.sh"
set -Eeuo pipefail

BASE="${DAEMEON_IMAGE_BASE:-${DAEMEONAI_HOME:-$HOME/daemeonai}/image-coding}"
IMG="${1:-}"

[[ -f "$IMG" ]] || { echo "Kuvaa ei löydy: $IMG" >&2; exit 2; }

case "${IMG,,}" in
  *.jpg|*.jpeg) ;;
  *) echo "Vain JPEG sallittu." >&2; exit 4 ;;
esac

command -v python3 >/dev/null || { echo "python3 puuttuu." >&2; exit 5; }
command -v curl >/dev/null || { echo "curl puuttuu." >&2; exit 6; }
command -v base64 >/dev/null || { echo "base64 puuttuu." >&2; exit 7; }

MODEL="${GEMINI_MODEL:-gemini-3.8-flash}"
NAME="$(basename "$IMG" | tr ' ' '_' | sed 's/[^A-Za-z0-9._-]/_/g')"
OUT="$BASE/results/${NAME%.*}-$(date +%Y%m%d-%H%M%S).json"

mkdir -p -- "$BASE/results"

case "${TEST_MODE:-}" in
  1|true|TRUE|yes|YES|on|ON)
    python3 - "$IMG" "$MODEL" > "$OUT" <<'PY'
import json
import os
import sys

image, model = sys.argv[1:]
json.dump(
    {
        "test_mode": True,
        "image": os.path.basename(image),
        "model": model,
    },
    sys.stdout,
)
sys.stdout.write("\n")
PY
    echo "HTTP_STATUS=TEST_MODE"
    echo "ANALYSIS_OK"
    echo "RESULT=$OUT"
    exit 0
    ;;
esac

[[ -n "${GEMINI_API_KEY:-}" ]] || {
  echo "GEMINI_API_KEY puuttuu." >&2
  exit 3
}

PROMPT_FILE="$BASE/prompts/coding.txt"
[[ -f "$PROMPT_FILE" ]] || {
  echo "Promptia ei löydy: $PROMPT_FILE" >&2
  exit 8
}

B64_FILE="$(mktemp)"
REQUEST_FILE="$(mktemp)"
trap 'rm -f -- "$B64_FILE" "$REQUEST_FILE"' EXIT

if ! base64 -w 0 "$IMG" > "$B64_FILE" 2>/dev/null; then
  if ! base64 "$IMG" | tr -d '\n' > "$B64_FILE"; then
    echo "Kuvan koodaus epäonnistui." >&2
    exit 9
  fi
fi

if ! python3 - "$PROMPT_FILE" "$B64_FILE" "$MODEL" > "$REQUEST_FILE" <<'PY'
import json
import sys

prompt_file, b64_file, model = sys.argv[1:]

with open(prompt_file, "r", encoding="utf-8") as prompt_handle:
    prompt = prompt_handle.read()

with open(b64_file, "r", encoding="ascii") as b64_handle:
    b64 = b64_handle.read().strip()

json.dump(
    {
        "model": model,
        "input": [
            {
                "role": "user",
                "content": [
                    {"type": "input_text", "text": prompt},
                    {
                        "type": "input_image",
                        "image_url": "data:image/jpeg;base64," + b64,
                    },
                ],
            }
        ],
    },
    sys.stdout,
)
PY
then
  echo "Pyyntöä ei voitu muodostaa." >&2
  exit 9
fi

HTTP=""
if HTTP="$(curl -sS -o "$OUT" -w '%{http_code}' \
  --connect-timeout 15 \
  --max-time 300 \
  https://generativelanguage.googleapis.com/v1beta/openai//responses \
  -H "Authorization: Bearer $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary "@$REQUEST_FILE")"; then
  :
else
  CURL_STATUS=$?
  echo "API-yhteys epäonnistui (curl $CURL_STATUS)." >&2
  [[ -s "$OUT" ]] && cat "$OUT" >&2
  exit 11
fi

echo "HTTP_STATUS=$HTTP"

if [[ "$HTTP" != 2* ]]; then
  echo "API_ERROR:" >&2
  cat "$OUT" >&2
  exit 10
fi

echo "ANALYSIS_OK"
echo "RESULT=$OUT"
