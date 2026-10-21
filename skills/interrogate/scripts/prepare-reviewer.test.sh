#!/usr/bin/env bash
# Behaviour test for prepare-reviewer. Run directly or through scripts/check.sh.
# shellcheck source=scripts/test-lib.sh
source "$(dirname "$0")/../../../scripts/test-lib.sh"

prep=$(cd "$(dirname "$0")" && pwd)/prepare-reviewer
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir "$scratch/tmp"
export TMPDIR=$scratch/tmp

repo=$scratch/repo
git init -q "$repo"
cd "$repo"
echo a > f.txt && git add -A && git commit -q -m base
echo b > f.txt && git commit -q -am head
echo c > f.txt && git commit -q -am later
git checkout -q HEAD~1
mid=$(git rev-parse HEAD)
git checkout -q -

worktrees() { git worktree list | wc -l | tr -d ' '; }
leftovers() { find "$scratch/tmp" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' '; }

out=$("$prep" --head HEAD~1 --base HEAD~2 --intent - <<'INTENT'
Para `one` $HOME.
INTENT
)
dir=$(sed -n 's/^prompt=\(.*\)\/prompt.md wt=.*/\1/p' <<<"$out")
check "it prints the prompt and worktree paths" "prompt=$dir/prompt.md wt=$dir/wt" "$out"
check "the worktree is at --head, resolved once to the full sha" "$mid" "$(git -C "$dir/wt" rev-parse HEAD)"
check "the prompt names the full head sha" yes "$(grep -qF "$mid" "$dir/prompt.md" && echo yes || echo no)"
check "the worktree is detached" "HEAD" "$(git -C "$dir/wt" rev-parse --abbrev-ref HEAD)"
check "  and registered with the reviewed repo" "2" "$(worktrees)"
# shellcheck disable=SC2016
check "the heredoc intent reaches the prompt literally" '> Para `one` $HOME.' "$(grep -F '> Para' "$dir/prompt.md")"

sub=$(mktemp -d "$repo/sub.XXXX")
out2=$(cd "$sub" && "$prep" --head HEAD --base HEAD~1 --intent x)
check "it works from a subdirectory of the reviewed repo" "$(git rev-parse HEAD)" "$(git -C "${out2##* wt=}" rev-parse HEAD)"
rmdir "$sub"

git worktree remove -f -f "$dir/wt"; rm -rf "$dir"
wt2=${out2##* wt=}
git worktree remove -f -f "$wt2"; rm -rf "${wt2%/wt}"
check "the cleanup loop's commands remove it all" "1 0" "$(worktrees) $(leftovers)"

check "a failed render fails before any worktree" "render-prompt: --exclude nosuch: matches no changed path" \
  "$("$prep" --head HEAD --base HEAD~1 --exclude nosuch --intent x 2>&1 || true)"
check "  and leaves nothing behind" "1 0" "$(worktrees) $(leftovers)"

git branch -q taken HEAD
mkdir "$scratch/bin"
cat > "$scratch/bin/git" <<STUB
#!/usr/bin/env bash
[ "\$1 \$2" = "worktree add" ] && { echo "fatal: stub refuses worktree add" >&2; exit 128; }
exec $(command -v git) "\$@"
STUB
chmod +x "$scratch/bin/git"
if PATH=$scratch/bin:$PATH "$prep" --head HEAD --base HEAD~1 --intent x >/dev/null 2>&1; then status=0; else status=$?; fi
check "a failed worktree add exits nonzero and removes the prompt dir" "1 1 0" "$status $(worktrees) $(leftovers)"

check "a bad --head names it" "prepare-reviewer: --head nosuch: not a commit" \
  "$("$prep" --head nosuch --base HEAD~1 --intent x 2>&1 || true)"
check "--head is required" "prepare-reviewer: --head <sha> is required" \
  "$("$prep" --base HEAD~1 --intent x 2>&1 || true)"
check "--head=<sha> is not taken for --head" "prepare-reviewer: --head <sha> is required" \
  "$("$prep" --head=HEAD --base HEAD~1 --intent x 2>&1 || true)"
check "  and leaves nothing behind" "1 0" "$(worktrees) $(leftovers)"

finish
