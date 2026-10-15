# Sourced by every skills/*/scripts/*.test.sh: check, finish, and a FAIL line when the test aborts.
# shellcheck shell=bash
set -euo pipefail
failures=0
trap 'echo "FAIL ${0##*/} aborted at line $LINENO: $BASH_COMMAND"' ERR

check() {
  local name=$1 expected=$2 actual=$3
  if [ "$expected" = "$actual" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name"
    diff <(echo "$expected") <(echo "$actual") | sed 's/^/     /' || true
    failures=$((failures + 1))
  fi
}

finish() {
  if [ "$failures" -gt 0 ]; then
    echo "${0##*/}: $failures failed"
    exit 1
  fi
  echo "${0##*/}: ok"
}
