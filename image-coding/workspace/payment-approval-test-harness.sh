# Purpose: Simulate payment approval dialog outcomes


#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

PAYMENT_EXECUTION=false
MAX_RETRIES=3
CORRELATION_ID="${CORRELATION_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
LOG_DIR="${LOG_DIR:-$HOME/daemeonai/image-coding/logs}"
LOG="$LOG_DIR/payment-approval-harness.log"

mkdir -p "$LOG_DIR"

log() {
    local level="$1" event="$2" detail="${3:-}"
    printf '%s correlation_id=%s level=%s event=%s detail=%q PAYMENT=NOT_SENT\n' \
        "$(date -Iseconds)" "$CORRELATION_ID" "$level" "$event" "$detail" >> "$LOG"
}

cleanup() {
    local rc=$?
    log INFO cleanup "rc=$rc"
    if command -v termux-wake-unlock >/dev/null 2>&1; then
        termux-wake-unlock >/dev/null 2>&1 || true
    fi
    return "$rc"
}
trap cleanup EXIT INT TERM

classify_dialog() {
    local code="${1:-}" text="${2:-}"
    text="${text,,}"

    if [[ "$code" == "-2" ]]; then
        echo REJECTED
    elif [[ "$code" == "0" && "$text" =~ ^(yes|y|kyllä|hyväksy|hyvaksy)$ ]]; then
        echo ACCEPTED
    elif [[ "$text" =~ ^(yes|y|kyllä|hyväksy|hyvaksy)$ ]]; then
        echo ACCEPTED
    elif [[ "$code" == "0" && "$text" =~ ^(no|n|ei|hylkää|hylkaa)$ ]]; then
        echo REJECTED
    elif [[ "$text" =~ ^(no|n|ei|hylkää|hylkaa)$ ]]; then
        echo REJECTED
    elif [[ "$code" == "TIMEOUT" || "$text" == "timeout" ]]; then
        echo TIMEOUT
    elif [[ "$code" == "API_ERROR" ]]; then
        echo API_ERROR
    else
        echo UNKNOWN
    fi
}

approval_result() {
    local code="${1:-}" text="${2:-}"
    local result
    result="$(classify_dialog "$code" "$text")"
    log INFO approval "result=$result code=$code text=$text"

    case "$result" in
        ACCEPTED)
            echo "APPROVAL=ACCEPTED"
            echo "PAYMENT=NOT_SENT"
            ;;
        REJECTED|TIMEOUT|UNKNOWN|API_ERROR)
            echo "APPROVAL=$result"
            echo "PAYMENT=NOT_SENT"
            ;;
    esac
}

localhost_diagnostic() {
    local url="${1:-http://127.0.0.1:8080/w}"
    local result
    result="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 "$url" 2>/dev/null || echo 000)"
    log INFO localhost "url=$url http_code=$result"

    if [[ "$result" == "000" ]]; then
        echo "SERVER=UNREACHABLE"
    elif [[ "$result" == "404" ]]; then
        echo "SERVER=HTTP_404"
    else
        echo "SERVER=HTTP_$result"
    fi
}

approval_result "${1:-UNKNOWN}" "${2:-}"
localhost_diagnostic "${3:-http://127.0.0.1:8080/w}"

echo "PAYMENT_EXECUTION=false"
echo "HARNESS=DRY_RUN"
