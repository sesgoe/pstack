---
name: retro
description: The user's retrospective on a session. Runs reflect with local overrides so each lesson lands in its right home (a skill, the repo's AGENTS.md or docs, the global AGENTS.md, or a check built by correct). Use for /retro.
disable-model-invocation: true
---

# Retro

Retro is reflect plus the local overrides below. This file owns the user's additions, so reflect can stay close to upstream. A new override goes here, not in reflect.

1. Read the `writing-for-agents` skill. Every AGENTS.md line, doc pointer, and skill text this run writes follows it.
2. Read the `reflect` skill's SKILL.md and its `references/` in full, and follow it for the whole run: transcript lookup, the three reviewers, the synthesizer, the structural check, the approval gate, and the summary.
3. Apply the overrides below. Where one disagrees with reflect, the override wins.

Every skill named here sits beside this one: `~/.claude/skills/<name>/SKILL.md` in Claude Code, `~/.agents/skills/<name>/SKILL.md` in Codex. Most are hidden from your skill list. Read them by that path.

## Overrides

### Reviewer prompts

Pass each reflect reviewer template verbatim, then append this block:

> **Additional lenses (retro).** Also look for these, and give each finding the same Principle / Evidence / Routing fields:
> - **Navigation:** the agent spent long finding a file or fact. Would a pointer in the repo's AGENTS.md or a doc it links to have saved that?
> - **Guardrails:** a mistake a check could have caught (lint, types, test, hook, CI, script). Read the repo's own check command and CI first: a check that exists but is unwired or broken is the finding. A repo with no guardrail at all is a finding.
> - **Steering bloat:** AGENTS.md lines (repo or global) that changed nothing, or that a check or a doc pointer should replace.
> - **Tool economy:** expensive or repeated tool calls a script, flag, or cached result would cut.
> - **Information access:** a fact the agent needed but could not reach (logs, read-only access to a service, a doc).
> - **Repo lessons:** facts about this repo or machine that are not about any skill (shared checkouts, environment quirks, procedures). Route them to the repo's AGENTS.md or a doc it links to.
>
> The "Scope to skills" rule above applies only to findings routed to a skill. Findings from these lenses route to `repo AGENTS.md: <path>`, `repo doc: <path>`, `global AGENTS.md`, or `correct: <the repeated mistake>`, and need no skill to have been used.
>
> Other reviewers run at the same time: write any transcript extract or scratch file to your own `mktemp -d` directory, never a fixed path like `/tmp/tx.txt`.

### Synthesizer prompt

Pass reflect's synthesizer template verbatim, with the reviewer outputs inlined, then append this block:

> **Routing overrides (retro).** These replace the matching rules above.
> - Routing targets, in addition to skill edits:
>   - `repo AGENTS.md: <path>`, or `repo doc: <path>` reached by a pointer from it. For lessons about one repo or machine. AGENTS.md takes pointers and short rules only; detail goes in a doc.
>   - `global AGENTS.md`: for cross-repo preferences of the user. Its source is `agents/AGENTS.md` in github.com/sesgoe/fleet, not the installed copy.
>   - `correct: <the repeated mistake>`: for anything a check could enforce (architecture, types, lint, test, hook, script). This replaces reflect's "route to Backlog" for mechanisms: the `correct` skill builds the check and proves it fails on the real past mistake.
> - Skill-was-used applies only to skill-edit rows. A repo, global, or correct row needs no skill to have been invoked.
> - Backlog: there is no tracker. List backlog items in the output for the user to decide; file nothing.
>
> Write any scratch file to your own `mktemp -d` directory.

### Apply

- Present the full Accepted / Rejected / Backlog output and wait for the user's approval, as reflect says. Apply only what the user approves.
- `correct:` rows: run the `correct` skill on that mistake, after approval.
- Repo and global AGENTS.md edits follow that repo's own rules for commits and pushes.
- Skill edits to pstack skills go to the user's fork (`~/personal/pstack`, see its `FORK.md`): upstream skills get the smallest edit that works, and new behavior goes into a local wrapper like this one.
