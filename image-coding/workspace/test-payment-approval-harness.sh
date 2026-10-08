# Purpose: Test payment approval harness cases


#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
H="$HOME/daemeonai/image-coding/workspace/payment-approval-test-harness.sh"
fail=0
run_test() {
    local name="$1" code="$2" text="$3" expected="$4"
    out="$(bash "$H" "$code" "$text" "http://127.0.0.1:1/w")"
    if grep -q "APPROVAL=$expected" <<<"$out" && grep -q 'PAYMENT=NOT_SENT' <<<"$out"; then
        echo "PASS $name"
    else
        echo "FAIL $name"
        printf '%s\n' "$out"
        fail=1
    fi
}
run_test "YES" 0 yes ACCEPTED
run_test "FINNISH_YES" 0 kyllä ACCEPTED
run_test "NO" 0 no REJECTED
run_test "CANCEL" -2 "" REJECTED
run_test "TIMEOUT" TIMEOUT "" TIMEOUT
run_test "UNKNOWN" 0 maybe UNKNOWN
run_test "API_ERROR" API_ERROR "" API_ERROR
if [[ "$fail" -eq 0 ]]; then
    echo "ALL_MOCK_TESTS=PASS"
    echo "REAL_PAYMENT=DISABLED"
else
    echo "ALL_MOCK_TESTS=FAIL"
    exit 1
fi
