# Purpose: Bridge image analysis output to code generation request


#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

BASE="${DAEMEON_IMAGE_BASE:-${DAEMEONAI_HOME:-$HOME/daemeonai}/image-coding}"
REQ="$BASE/queue/jpeg-generation.json"
CODE="$BASE/workspace/generated-code.sh"

mkdir -p "$BASE/queue" "$BASE/workspace" "$BASE/generated" "$BASE/logs"

if ! command -v jq >/dev/null 2>&1; then
    echo "JQ_NOT_FOUND" >&2
    exit 1
fi

if ! command -v find >/dev/null 2>&1 || ! command -v sort >/dev/null 2>&1; then
    echo "REQUIRED_FILE_UTILITIES_NOT_FOUND" >&2
    exit 1
fi

SOURCE=""
RAW=""

if [[ -d "$BASE/results" ]]; then
    while IFS= read -r -d '' F; do
        R="$(jq -r '.analysis.raw_output // empty' "$F" 2>/dev/null || true)"
        if [[ -n "$R" && "$R" != "null" ]]; then
            SOURCE="$F"
            RAW="$R"
            break
        fi
    done < <(find "$BASE/results" -type f -name '*.json' -print0 | sort -z)
fi

if [[ -z "$RAW" ]]; then
    echo "NO_RAW_ANALYSIS_FOUND"
    exit 0
fi

FOUND="$(
    printf '%s\n' "$RAW" | awk '
        BEGIN {
            in_block = 0
            block_found = 0
            line_count = 0
        }

        !block_found && $0 ~ /^[[:space:]]*```(bash|sh|shell)([[:space:]].*)?[[:space:]]*$/ {
            in_block = 1
            block_found = 1
            next
        }

        in_block && $0 ~ /^[[:space:]]*```[[:space:]]*$/ {
            exit
        }

        in_block && line_count < 200 {
            print
            line_count++
        }
    '
)"

if [[ -z "$FOUND" ]]; then
    echo "NO_CODE_BLOCK_IN_RAW_OUTPUT"
    echo "SOURCE=$SOURCE"
    exit 0
fi

CODE_TMP="$(mktemp "$BASE/workspace/.generated-code.XXXXXX")"
REQ_TMP=""
cleanup() {
    rm -f -- "$CODE_TMP" "${REQ_TMP:-}"
}
trap cleanup EXIT

{
    printf '%s\n' '#!/data/data/com.termux/files/usr/bin/bash'
    printf '%s\n' "$FOUND"
} > "$CODE_TMP"

chmod 700 "$CODE_TMP"

if ! bash -n "$CODE_TMP"; then
    echo "GENERATED_CODE_SYNTAX_FAILED"
    echo "CODE=$CODE"
    exit 1
fi

mv -f -- "$CODE_TMP" "$CODE"
CODE_TMP=""

OUT="$BASE/generated/jpeg-$(date +%Y%m%d-%H%M%S).jpeg"

REQ_TMP="$(mktemp "$BASE/queue/.jpeg-generation.XXXXXX")"

jq -n \
  --arg source "$SOURCE" \
  --arg code "$CODE" \
  --arg output "$OUT" \
  '{
    operation:"IMAGE_GENERATION_WITH_CODE_FIX",
    status:"PENDING_APPROVAL",
    human_approval_required:true,
    execution_allowed:false,
    write_allowed:false,
    payment_execution:false,
    source_analysis:$source,
    code_path:$code,
    output:$output,
    smoke_test:"bash -n + controlled execution"
  }' > "$REQ_TMP"

mv -f -- "$REQ_TMP" "$REQ"
REQ_TMP=""

echo "BRIDGE=CONNECTED"
echo "SOURCE=$SOURCE"
echo "CODE=$CODE"
echo "REQUEST=$REQ"
echo "STATUS=PENDING_APPROVAL"
