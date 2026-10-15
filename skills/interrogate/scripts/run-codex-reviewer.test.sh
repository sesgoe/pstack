#!/usr/bin/env bash
# Behaviour test for run-codex-reviewer, with codex stubbed. Run directly or through scripts/check.sh.
set -euo pipefail

run=$(cd "$(dirname "$0")" && pwd)/run-codex-reviewer
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
failures=0

mkdir "$scratch/bin" "$scratch/tmp"
cat > "$scratch/bin/codex" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CODEX_LOG/args"
cat > "$CODEX_LOG/stdin"
while [ $# -gt 0 ]; do
  case $1 in
    -C) git -C "$2" rev-parse HEAD > "$CODEX_LOG/head"; shift 2 ;;
    -o) echo review > "$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [ -n "${CODEX_HANG:-}" ]; then echo $$ > "$CODEX_LOG/hung"; exec sleep 30; fi
exit "${CODEX_EXIT:-0}"
EOF
chmod +x "$scratch/bin/codex"
export PATH=$scratch/bin:$PATH TMPDIR=$scratch/tmp CODEX_LOG=$scratch

repo=$scratch/repo
git init -q "$repo"
cd "$repo"
echo a > f.txt && git add -A && git commit -q -m base
echo b > f.txt && git commit -q -am head

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
worktrees() { git worktree list | wc -l | tr -d ' '; }

out=$("$run" --model m1 --effort high --head HEAD --base HEAD~1 --intent - 2>&1 <<'EOF'
Para `one` $HOME.
EOF
) || true
dir=$(sed -n 's/^prompt=\(.*\)\/prompt.md out=.*/\1/p' <<<"$out")
check "it prints the prompt and out paths" "prompt=$dir/prompt.md out=$dir/out.md" "$out"
check "codex gets the model, effort, worktree, and out path" "exec
-m
m1
-c
model_reasoning_effort=high
--dangerously-bypass-approvals-and-sandbox
-C
$dir/wt
-o
$dir/out.md
-" "$(cat "$scratch/args")"
check "codex reads the rendered prompt on stdin" "$(cat "$dir/prompt.md")" "$(cat "$scratch/stdin")"
check "codex runs in a worktree at --head" "$(git rev-parse HEAD)" "$(cat "$scratch/head")"
check "codex's review is in out.md" review "$(cat "$dir/out.md")"
check "the worktree is removed after codex exits" "1 absent" "$(worktrees) $([ -e "$dir/wt" ] && echo present || echo absent)"

if CODEX_EXIT=3 "$run" --model m1 --effort high --head HEAD --base HEAD~1 --intent x >/dev/null 2>&1; then status=0; else status=$?; fi
check "a failed codex run exits with its status and removes the worktree" "3 1" "$status $(worktrees)"

# shellcheck disable=SC2016
check "the heredoc intent reaches the prompt literally" '> Para `one` $HOME.' "$(grep -F '> Para' "$dir/prompt.md")"

CODEX_HANG=1 "$run" --model m1 --effort high --head HEAD --base HEAD~1 --intent x >/dev/null 2>&1 &
launcher=$!
for _ in $(seq 50); do [ -s "$scratch/hung" ] && break; sleep 0.1; done
kill -TERM "$launcher" 2>/dev/null || true
for _ in $(seq 20); do kill -0 "$launcher" 2>/dev/null || break; sleep 0.1; done
if wait "$launcher"; then status=0; else status=$?; fi
alive() { kill -0 "$1" 2>/dev/null && echo alive || echo gone; }
check "SIGTERM stops a running codex, exits 130, and removes the worktree" "codex ran, 130 gone 1" \
  "$([ -s "$scratch/hung" ] && echo "codex ran," || echo "codex never ran,") $status $(alive "$(cat "$scratch/hung")") $(worktrees)"

rm -rf "$scratch/args" "$scratch"/tmp/*
check "a failed render fails before any worktree or codex run" "render-prompt: --exclude nosuch: matches no changed path" \
  "$("$run" --model m1 --effort high --head HEAD --base HEAD~1 --exclude nosuch --intent x 2>&1 || true)"
check "  and leaves nothing behind" "1 0 no codex" \
  "$(worktrees) $(find "$scratch/tmp" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ') $([ -e "$scratch/args" ] && echo codex || echo no codex)"

check "a bad --head names it" "run-codex-reviewer: --head nosuch: not a commit" \
  "$("$run" --model m1 --effort high --head nosuch --base HEAD~1 --intent x 2>&1 || true)"
check "--model is required" "run-codex-reviewer: --model, --effort, and --head <sha> are required" \
  "$("$run" --effort high --head HEAD --base HEAD~1 --intent x 2>&1 || true)"
check "--head=<sha> is not taken for --head" "run-codex-reviewer: --model, --effort, and --head <sha> are required" \
  "$("$run" --model m1 --effort high --head=HEAD --base HEAD~1 --intent x 2>&1 || true)"

if [ "$failures" -gt 0 ]; then
  echo "run-codex-reviewer.test.sh: $failures failed"
  exit 1
fi
echo "run-codex-reviewer.test.sh: ok"
