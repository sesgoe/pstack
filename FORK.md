# sesgoe/pstack fork

A fork of [backnotprop/pstack](https://github.com/backnotprop/pstack) (itself a mirror of
`cursor/plugins/pstack`) with a few local edits. Installed for Claude Code and Codex by
`github.com/sesgoe/fleet` (`agents/skills.conf` pins a commit from this repo's `main`).

## Edits

- `skills/interrogate`: folds in the parts of Tim Vykruta's REVIEW.md
  (https://x.com/tvykruta/status/2106138761511727451) that pstack didn't already cover:
  - new `references/execute-and-probe.md`: write test inputs before reading the code, run them in
    a throwaway worktree against head and base, the probe list, honesty of data, a report on
    every design principle, attacking new gates and hooks, re-reading docs after moves;
  - reviewers may execute code (in a throwaway worktree, never the author's tree) instead of being read-only;
  - findings carry reproductions; reviewers report "N findings so far" and what they executed;
  - fix commits get their own review;
  - the verdict ends with `VERDICT: APPROVE` or `VERDICT: CHANGES`;
  - model invocation is allowed (no `disable-model-invocation`), so agents can run a review on
    their own work without the user typing `/interrogate`;
  - `codex:<model>` reviewer entries run through `codex exec` in their own worktree, with full,
    unsandboxed access, so a Claude-led review gets an OpenAI reviewer (2026-10-08);
  - every reviewer runs in its own git worktree (Claude Code `isolation: "worktree"`) and first
    checks out the reviewed SHA, because that worktree starts at the remote's default branch (2026-10-08).

- `skills/poteto-mode`: a "The user approves each push" non-negotiable and a **PR hand-off** step
  in `playbooks/opening-a-pr.md`. When the user's instructions reserve that call, every playbook
  stops before the first push: commits on a branch, an `interrogate` review (repeated after each
  fix) ending in `VERDICT: APPROVE`, then a hand-off with the PR title and body that asks for the
  go-ahead. On the go-ahead the agent pushes and opens the PRs. Force-push, merge, and auto-merge
  need their own ask.
  - The PR body has a `## Risk Analysis` section after `## Blast Radius` (2026-10-10): the door
    and rollback, rollout order and failure window, failure modes, and mitigations taken or
    skipped. Blast Radius keeps only who and what the change touches.

## Syncing with upstream

```sh
jj git fetch --remote upstream      # or: git fetch upstream
jj new main upstream/main -m "Merge upstream pstack"   # or: git merge upstream/main
# resolve conflicts in the files listed above, then push main and bump the pin in fleet
```
