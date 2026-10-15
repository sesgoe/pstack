#!/usr/bin/env bash
# Repo checks: every skills/*/scripts/*.test.sh, and shellcheck on every shell script. CI runs the same command (.github/workflows/check.yml).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
status=0
for test in skills/*/scripts/*.test.sh; do
  bash "$test" || { echo "FAIL $test: exited $?"; status=1; }
done
grep -lsE -d skip '^(#!/usr/bin/env (ba)?sh|#!/bin/(ba)?sh|# shellcheck shell=)' skills/*/scripts/* scripts/*.sh |
  xargs shellcheck -x || { echo "FAIL shellcheck"; status=1; }
[ "$status" = 0 ] && echo "check.sh: ok"
exit "$status"
