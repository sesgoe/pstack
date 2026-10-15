---
name: pr-mode
description: The user's standard flow for work that ends in a PR. Runs poteto-mode plus local triggers for verification, risk review, and babysitting. Use for /pr-mode.
disable-model-invocation: true
---

# PR mode

PR mode is poteto-mode plus the local triggers below. This file owns the user's own additions to the workflow, so poteto-mode can stay close to upstream. A new trigger goes here, not in poteto-mode.

1. Read the `poteto-mode` skill's SKILL.md in full and follow it for the whole task: its non-negotiables, triggers, principles, and playbooks.
2. Apply the local triggers on top. Where one disagrees with poteto-mode, the local trigger wins.

Every skill named here and in poteto-mode sits beside this one: `~/.claude/skills/<name>/SKILL.md` in Claude Code, `~/.agents/skills/<name>/SKILL.md` in Codex. Most are hidden from your skill list. Read them by that path.

## Local triggers

- **A hand-off or a stop-and-ask** (the PR hand-off, a convergence stop, any reply that waits on the user) → open it with the card below; the detail follows it. The user runs many workstreams and reads the card to re-enter this one, so write Goal and Problem in your own words from the original ask, not by copying the issue title. Number pull requests and issues as `pr#<n>` and `i#<n>`, per the global `AGENTS.md`; before the PR exists, write `pr# not opened`.

  ```
  <repo> pr#<n> · i#<n>, i#<n> · <branch>
  Goal: <what the user is after>
  Problem: <what stands in the way, which this change solves>
  State: ready to push | blocked on <x> | needs your call on <y>
  You: <the one thing you need from the user, or "nothing">
  ```

- **A behaviour claim for `## Verification`** (a bug no longer reproduces, an output changed, a number moved) → the `verify-this` skill. Each such Verification bullet states a claim it returned `VERIFIED` on. On `NOT VERIFIED` or `INCONCLUSIVE`, fix the change or drop the claim. A plain check run (`just check` passes) needs no `verify-this`.
- **Risk Analysis calls the change a one-way door**, or Blast Radius reaches stored data, another service, or users outside the change → recommend a `thermo-nuclear-code-quality-review` in the hand-off. Don't run it. The user is learning when it pays off, so name the signal that fired and give the full invocation to paste into a thread on the worktree: `/thermo-nuclear-code-quality-review Review branch <branch> against <base>.`
- **A review finding that only building a later step would fix** (a runbook, script, or tool for a step the issue or plan defers) → Consider, not Act On. Post it on the issue as a requirement for that step, and keep that step's artifacts out of this change.
- **A hand-off that closes its source issue while Consider or Noted findings remain** → list them in the hand-off and ask whether to file them as one follow-up issue, with steps and a "done when" line. Work in the `sesgoe/pstack` fork files in `sesgoe/agent-config`, since the fork has issues disabled.
- **The `interrogate` loop in `opening-a-pr` stops converging**: two rounds in a row whose Act On is mostly fallout from earlier rounds' fixes, message wording, or findings outside the intent's threat model once the original "done when" is met; a fix round that adds a new file or script, other than the test **Same Class Twice** asks for; a "do not re-report" list in the intent that grows across rounds; or a fifth round → stop and ask the user before another round. Give the scope now against the original ask, list what each extra round found, forecast what another round would find from those classes, and leave the remaining findings under Consider. Recommend another round only when the last one found a class the earlier rounds didn't.
