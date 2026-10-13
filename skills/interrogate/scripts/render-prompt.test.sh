#!/usr/bin/env bash
# Behaviour test for render-prompt. Run directly or through scripts/check.sh.
# RENDER_PROMPT=<path> runs it against another copy, e.g. an older commit's script.
set -euo pipefail

render_prompt=${RENDER_PROMPT:-$(cd "$(dirname "$0")" && pwd)/render-prompt}
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export TMPDIR=$scratch GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
failures=0

repo=$scratch/repo
git init -q "$repo"
cd "$repo"
for i in $(seq 1 12); do echo "line $i"; done > top.txt
mkdir -p sub a
echo b > sub/s.txt
seq 1 20 > a/x
git add -A && git commit -q -m base
sed -i 's/line 6/LINE 6/' top.txt
mkdir -p 'app/[id]' app/i
echo c > 'app/[id]/page.txt'
echo d > app/i/page.txt
echo u > 'café.txt'
printf 'caf\xe9\n' > latin.txt
git mv a/x a/y
git add -A && git commit -q -m head
cd sub

render() { "$render_prompt" --head HEAD --base HEAD~1 "$@"; }
diff_files() { grep '^diff --git' "$1" | sort; }

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

all_files='diff --git a/a/x b/a/y
diff --git a/app/[id]/page.txt b/app/[id]/page.txt
diff --git a/app/i/page.txt b/app/i/page.txt
diff --git a/café.txt b/café.txt
diff --git a/latin.txt b/latin.txt
diff --git a/top.txt b/top.txt'

if p=$(render --intent x 2>&1); then
  check "a subdirectory run renders the whole diff" "$all_files" "$(diff_files "$p")"
  baseline=$(cat "$p")
else
  check "a subdirectory run renders the whole diff" "$all_files" "render failed: $p"
  baseline=""
fi

excluded() {
  local name=$1 path=$2 gone=$3 p
  if p=$(render --intent x --exclude "$path" 2>&1); then
    check "$name" "$(grep -vxF "$gone" <<<"$all_files")" "$(diff_files "$p")"
  else
    check "$name" "$(grep -vxF "$gone" <<<"$all_files")" "render failed: $p"
  fi
}
excluded "--exclude takes a bracketed path literally" 'app/[id]/page.txt' 'diff --git a/app/[id]/page.txt b/app/[id]/page.txt'
excluded "--exclude matches a non-ASCII path" 'café.txt' 'diff --git a/café.txt b/café.txt'
excluded "--exclude normalizes ./" './top.txt' 'diff --git a/top.txt b/top.txt'

if p=$(render --intent x --exclude a/x --exclude a/y 2>&1); then
  check "--exclude takes both sides of a rename" "$(grep -v 'a/a/x' <<<"$all_files")" "$(diff_files "$p")"
else
  check "--exclude takes both sides of a rename" "$(grep -v 'a/a/x' <<<"$all_files")" "render failed: $p"
fi

for setting in diff.context=0 diff.noprefix=true color.ui=always core.quotePath=true diff.relative=true; do
  if p=$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=${setting%%=*} GIT_CONFIG_VALUE_0=${setting#*=} render --intent x 2>&1); then
    actual=$(cat "$p")
  else
    actual="render failed: $p"
  fi
  if [ -n "$baseline" ] && [ "$actual" = "$baseline" ]; then
    echo "ok   $setting leaves the prompt unchanged"
  else
    echo "FAIL $setting leaves the prompt unchanged"
    failures=$((failures + 1))
  fi
done

p=$(printf 'Para {HEAD_SHA} one.\n\nPara two.\n' | render --runner deploy.sh --intent -)
check "the intent is quoted line by line and kept literal" '> Para {HEAD_SHA} one.
>
> Para two.' "$(sed -n '/stated intent/,/^Review whether/p' "$p" | grep '^>')"
check "--runner adds the runner sentence" 'The prompt names you the runner of `deploy.sh`, so run it end to end.' \
  "$(grep -o 'The prompt names you the runner of .*' "$p")"

check "a typo'd --exclude fails" "render-prompt: --exclude nosuch.lock: matches no changed path" \
  "$(render --intent x --exclude nosuch.lock 2>&1 || true)"
check "an empty intent fails" "render-prompt: empty intent" "$(render --intent - </dev/null 2>&1 || true)"

if [ "$failures" -gt 0 ]; then
  echo "render-prompt.test.sh: $failures failed"
  exit 1
fi
echo "render-prompt.test.sh: ok"
