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

- **A behaviour claim for `## Verification`** (a bug no longer reproduces, an output changed, a number moved) → the `verify-this` skill. Each such Verification bullet states a claim it returned `VERIFIED` on. On `NOT VERIFIED` or `INCONCLUSIVE`, fix the change or drop the claim. A plain check run (`just check` passes) needs no `verify-this`.
- **Risk Analysis calls the change a one-way door**, or Blast Radius reaches stored data, another service, or users outside the change → recommend a `thermo-nuclear-code-quality-review` in the hand-off. Don't run it. The user is learning when it pays off, so name the signal that fired and give the full invocation to paste into a thread on the worktree: `/thermo-nuclear-code-quality-review Review branch <branch> against <base>.`
