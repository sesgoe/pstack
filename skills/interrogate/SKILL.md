---
name: interrogate
description: "Use for \"interrogate\", \"adversarial review\", \"multi-model review\", \"challenge this\", \"stress test this code\", \"find blind spots\", or \"tear this apart\", and for every code review of a branch, PR, or fix commit. Multiple LLM reviewers challenge changes from independent angles, executing the code rather than only reading it."
---

# Interrogate

Spawn one reviewer per configured model to adversarially review code changes. Each model gets the same prompt and rubric. The adversarial signal comes from model diversity, not assigned personas.

The deliverable is a synthesized verdict. Do NOT auto-apply changes.

## Step 1, Determine Scope

Identify what to review from context:

- If the user points at specific files or a diff, use that
- If on a feature branch, run `git diff main...HEAD` (or the appropriate base branch) for the full changeset
- If the user's message references recent work, gather the relevant files
- A fix commit made in response to an earlier review is its own scope and gets its own review. Fixes create bugs.

Reviewers are fresh subagents that did not write the code. The author's own pass over its work is a checklist pass, not a review.

Package the diff (or file contents) plus any surrounding context files the reviewers need to understand the code.

## Step 2, State the Intent

Before spawning reviewers, state the intent explicitly. Derive this from:

- The user's message
- Commit messages
- PR description if one exists
- The code itself

Write one clear paragraph. If you're unsure about the intent, ask the user before proceeding.

## Step 3, Spawn Reviewers

Launch all reviewers in a single message using the Task tool.

**Other harnesses.** The spawns in this skill use Cursor's `Task` tool. In another harness, use its subagent tool: `Agent` in Claude Code (`subagent_type: general-purpose`), `task` in OpenCode (`subagent_type: general`), `spawn_agent` in Codex. Keep the prompt and the model. Drop parameters your tool doesn't have. If your harness has no subagent tool, as in Pi without an extension, run each reviewer yourself, one after another.

Use the `interrogate reviewers` line in the pstack settings file (`~/.cursor/rules/pstack-models.mdc` in Cursor, `~/.agents/pstack-models.md` in other harnesses), one reviewer per entry, extending or shrinking the Reviewer A/B/C labels below to the configured entry count. If the file or that line is missing, use the table defaults.

| Subagent | Default model |
|----------|---------------|
| Reviewer A | `claude-opus-5-5-max` |
| Reviewer B | `gpt-5.6-sol-max` |
| Reviewer C | `grok-4.7-xhigh-fast` |

For each reviewer:
- `subagent_type`: `generalPurpose`
- `model`: the configured `interrogate reviewers` entry, or the table default with no configured line. For an `auto` or `inherit-parent` entry, omit `model` so that reviewer runs on the parent model.
- Every reviewer runs in its own git worktree, so it can't touch the author's tree. In Claude Code, pass `isolation: "worktree"`. That worktree starts at the remote's default branch, not the reviewed commit, and the prompt's first step checks out `{HEAD_SHA}`. A `codex:` entry gets its worktree from the steps below. In a harness with neither, create one per reviewer as in step 1 below and start the reviewer in it. Where your tool has a `readonly` flag, leave it off so reviewers can run code.

**`codex:<model>` entries** (for example `codex:gpt-6-astra`) run that reviewer through the Codex CLI instead of your subagent tool, so a Claude-led review still gets an OpenAI reviewer. The panel crosses vendors to cover blind spots from one lab's training. For each such entry:

1. Create the reviewer's own worktree at the reviewed commit: `wt=$(mktemp -d) && git worktree add --detach "$wt" <head>`.
2. Write the filled reviewer prompt to a file outside the worktree, then run in the background (in Claude Code, `Bash` with `run_in_background`; you are notified when it exits):
   `codex exec -m <model> -c model_reasoning_effort=<effort> --dangerously-bypass-approvals-and-sandbox -C "$wt" -o <out>.md - < <prompt>.md`
   `<effort>` is the effort in the settings file's `# budget` line (for example `high`), or `high` without one. The reviewer has full, unsandboxed access, including the network, so it can install and run anything.
3. Spawn the other reviewers in the same message. When the command exits, read `<out>.md` as that reviewer's result, then `git worktree remove --force "$wt"`.

If `codex` is missing or the run fails, retry once. Never substitute a model from the parent's vendor. Name the failure under **Reviewers**. The verdict can't be `VERDICT: APPROVE` until a codex reviewer has run.

If your subagent tool rejects a configured entry, run that reviewer on the table default of its family and say so. Families go by prefix: `claude-*`, `gpt-*`, and `grok-*`. With no family match, use Reviewer A's default. If it rejects a table default, check the valid slugs in its error message or your harness's model list, pick the closest equivalent (prefer the highest-reasoning tier of the same family), spawn with it, and open a separate PR to update the default table. Do not block the review on the slug issue. Never treat an alias entry as a rejected slug or apply either fallback to it.

Read `references/reviewer-prompt.md` and fill in the template with:
1. The stated intent and the full SHA of the reviewed commit (`{HEAD_SHA}`)
2. The diff or file contents
3. The review rubric from `references/rubric.md`
4. The code-quality lens from `references/code-quality-review.md`
5. The execute-and-probe lens from `references/execute-and-probe.md`

The same filled template goes to all reviewers, so every model applies all three lenses.

## Step 4, Synthesize

As results come back, build a unified picture:

1. **Parse all findings** from the reviewers
2. **Identify consensus**. Findings raised by 2+ models independently are highest signal.
3. **Identify lone-model findings**. Still worth reading, but weight accordingly.
4. **Deduplicate**. Different models may describe the same issue differently. Merge these and note which models raised it.
5. **Note disagreements**. If one model flags something and another explicitly says the opposite, that's useful context for the verdict.

## Step 5, Lead Judgment

You are the lead reviewer, a pragmatic senior engineer, not a neutral aggregator.

Read `references/lead-judgment.md` for the full framework.

Categorize every finding using these buckets:

- **Act on**. Real issues affecting correctness, security, or maintainability given the actual goals. These would block a real PR.
- **Consider**. Legitimate points, but you're not sure they outweigh the cost of addressing them right now. Worth the user's attention.
- **Noted**. Technically valid but not actionable. Context-dependent, premature optimization, or low-impact given the current stage.
- **Dismissed**. Wrong, nitpicky, or missing context. Brief explanation why.

For each finding, include:
- Which model(s) raised it
- The category (act on / consider / noted / dismissed)
- A one-line rationale for the categorization

## Output Format

Present the verdict in this structure:

### Intent
> [The stated intent paragraph from Step 2]

### Reviewers
- Reviewer [label]: [model name], [N findings] (one bullet per reviewer)

### Act On
[Findings that should be addressed. For each: description, which models raised it, why it matters.]

### Consider
[Findings worth thinking about. For each: description, which models raised it, tradeoff involved.]

### Noted
[Valid but low-priority. Brief list.]

### Dismissed
[Rejected findings with brief rationale.]

### Agreement Map
[Where did models agree, where did they diverge, and what does the pattern of agreement/disagreement tell us?]

### Design Principles
[One line each for separation of concerns, programming by intention, encapsulation, high cohesion, low coupling: OK, or the violation with file:line.]

### Executed
[What the reviewers actually ran, against head and base. Green tests alone are not evidence.]

End with exactly one line: `VERDICT: APPROVE` when Act On is empty, otherwise `VERDICT: CHANGES`.
