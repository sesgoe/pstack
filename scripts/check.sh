#!/usr/bin/env bash
# Repo checks: every skills/*/scripts/*.test.sh. CI runs the same command (.github/workflows/check.yml).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
status=0
for test in skills/*/scripts/*.test.sh; do
  bash "$test" || { echo "FAIL $test: exited $?"; status=1; }
done
[ "$status" = 0 ] && echo "check.sh: ok"
exit "$status"
