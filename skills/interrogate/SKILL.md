---
name: interrogate
description: "Use for \"interrogate\", \"adversarial review\", \"multi-model review\", \"challenge this\", \"stress test this code\", \"find blind spots\", or \"tear this apart\", and for every code review of a branch, PR, or fix commit. Multiple LLM reviewers challenge changes from independent angles, executing the code rather than only reading it."
---

# Interrogate

Spawn one reviewer per configured model to adversarially review code changes. The adversarial signal comes from model diversity, not assigned personas. The deliverable is a synthesized verdict. Do NOT auto-apply changes.

## Step 1, Scope

Identify what to review from context:

- If the user points at specific files or a diff, use that.
- If on a feature branch, run `git diff main...HEAD` (or the appropriate base branch) for the full changeset.
- If the user's message references recent work, gather the relevant files.
- A fix commit made in response to an earlier review is its own scope and gets its own review. Fixes create bugs.
- Before `VERDICT: APPROVE` on a change that took more than one fix round, review the whole series against the base once more. Each round's scope sees only its own commit, never how the commits fit together.

Reviewers are fresh subagents that did not write the code. The author's own pass over its work is a checklist pass, not a review.

Package the diff or file contents with any surrounding context files the reviewers need to understand the code.

## Step 2, Intent

Before spawning reviewers, state the intent in one clear paragraph from the user's message, commit messages, the PR description if one exists, and the code. If you're unsure about the intent, ask the user before proceeding.

The paragraph names the threat model: who sends the traffic or calls the code, and what that client actually sends. A finding that needs a client or adversary outside it goes under Noted.

## Step 3, Spawn Reviewers

Launch all reviewers in a single message with the Task tool, one per entry on the `interrogate reviewers` line in the pstack settings file (`~/.cursor/rules/pstack-models.mdc` in Cursor, `~/.agents/pstack-models.md` in other harnesses), labeled Reviewer A, B, and so on to match the entry count. If the file or that line is missing, use the table defaults.

**Other harnesses.** The spawns in this skill use Cursor's `Task` tool. In another harness, use its subagent tool: `Agent` in Claude Code (`subagent_type: general-purpose`), `task` in OpenCode (`subagent_type: general`), `spawn_agent` in Codex. Keep the prompt and the model. Drop parameters your tool doesn't have. If your harness has no subagent tool, as in Pi without an extension, run each reviewer yourself, one after another.

| Subagent | Default model |
|----------|---------------|
| Reviewer A | `claude-opus-5-5-xhigh` |
| Reviewer B | `grok-4.7-xhigh-fast` |

Each reviewer gets `subagent_type: generalPurpose` and `model` set to its configured entry, or its table default when there is no configured line. Omit `model` for an `auto` or `inherit-parent` entry, so that reviewer runs on the parent model.

Every reviewer runs in its own git worktree, so it can't touch the author's tree. In Claude Code, pass `isolation: "worktree"`. That worktree starts at the remote's default branch, not the reviewed commit, and the prompt's first step checks out `{HEAD_SHA}`. A `codex:` entry gets its worktree from the steps below. In a harness with neither, create one per reviewer as in step 1 below and start the reviewer in it. Where your tool has a `readonly` flag, leave it off so reviewers can run code.

A worktree doesn't contain a script that writes outside it (to another host, or to a path in the user's home or on a Windows drive). When the change has one, render one reviewer's prompt with `--runner <script>` to name it that script's runner; the others run its pieces.

**`codex:<model>` entries** (for example `codex:gpt-6-astra`) run that reviewer through the Codex CLI instead of your subagent tool, so a Claude-led review still gets an OpenAI reviewer. The panel crosses vendors to cover blind spots from one lab's training. For each such entry:

1. Create the reviewer's own worktree at the reviewed commit: `wt=$(mktemp -d) && git worktree add --detach "$wt" <head>`.
2. Render the reviewer's prompt into `$p` as below, then run in the background (in Claude Code, `Bash` with `run_in_background`; you are notified when it exits):
   `codex exec -m <model> -c model_reasoning_effort=<effort> --dangerously-bypass-approvals-and-sandbox -C "$wt" -o "${p%/*}/out.md" - < "$p"`
   `<effort>` is the effort in the settings file's `# budget` line (for example `high`), or `high` without one. The reviewer has full, unsandboxed access, including the network, so it can install and run anything.
3. Spawn the other reviewers in the same message. When the command exits, read `${p%/*}/out.md` as that reviewer's result, then `git worktree remove --force "$wt"`.

**After the verdict**, remove the Claude Code reviewers' worktrees too. `isolation: "worktree"` leaves each one, locked, under the main checkout's `.claude/worktrees/agent-<id>` on a `worktree-agent-<id>` branch. For each: `git worktree remove -f -f <path>` (a locked worktree needs both), then `git branch -D worktree-agent-<id>`. Then remove the directory of every prompt path `render-prompt` printed this round, by its literal path; shell variables don't survive between tool calls.

If `codex` is missing or the run fails, retry once. Never substitute a model from the parent's vendor. Name the failure under **Reviewers**. The verdict can't be `VERDICT: APPROVE` until a codex reviewer has run.

If your subagent tool rejects a configured entry, run that reviewer on its family's table default and say so. Families go by prefix: `claude-*` and `grok-*`. With no family match, use Reviewer A's default. If it rejects a table default, spawn with the closest equivalent from the valid slugs in its error message or your harness's model list (prefer the same family and reasoning tier), and open a separate PR to update the default table. Do not block the review on the slug issue. Never treat an alias entry as a rejected slug or apply either fallback to it.

Render each reviewer's prompt with one call from anywhere in the reviewed repo, where `<skill>` is this skill's directory:

```sh
p=$(<skill>/scripts/render-prompt --head <sha> --base <ref> [--exclude <path>]... [--runner <script>] --intent - <<'EOF'
<Step 2 paragraph>
EOF
)
```

It fills `references/reviewer-prompt.md` with the intent, the full head SHA, the `<base>...<head>` diff (minus each `--exclude` path, given from the repo root, such as `flake.lock`; an exclude that matches no changed path is an error), and the rubric, code-quality, and execute-and-probe references, so every model applies all three lenses. It writes `prompt.md` into a fresh temp directory and prints that path. The quoted heredoc keeps the shell from expanding backticks or `$` in the paragraph. A Claude Code reviewer's whole Agent prompt is `Read <path> in full and follow it.` A scope that isn't a diff (files the user points at) still gets the template filled by hand: the intent as a blockquote, and `{RUNNER}` empty unless that reviewer is the runner.

## Step 4, Synthesize

As results come back, build a unified picture. Parse every reviewer's findings. Merge findings that describe the same issue differently, and note which models raised each one. Findings two or more models raised independently are the highest signal. Read a lone model's finding, but weight it accordingly. Note disagreements. If one model flags something and another explicitly says the opposite, that is context for the verdict.

## Step 5, Lead Judgment

You are the lead reviewer, a pragmatic senior engineer, not a neutral aggregator. Read `references/lead-judgment.md` for the full framework. Put every finding in one of four buckets, with the model(s) that raised it and a one-line rationale.

- **Act on**. Real issues affecting correctness, security, or maintainability given the actual goals. They would block a real PR.
- **Consider**. Legitimate, but you're not sure they outweigh the cost of addressing them now. Worth the user's attention.
- **Noted**. Technically valid but not actionable. Context-dependent, premature optimization, or low-impact at this stage.
- **Dismissed**. Wrong, nitpicky, or missing context, with a brief reason.

## Output Format

### Intent
> [The stated intent paragraph from Step 2]

### Reviewers
- Reviewer [label]: [model name], [N findings] (one bullet per reviewer)

### Act On
[Each: description, which models raised it, why it matters.]

### Consider
[Each: description, which models raised it, the tradeoff.]

### Noted
[Brief list.]

### Dismissed
[Each with a brief rationale.]

### Agreement Map
[Where models agreed and diverged, and what that pattern tells us.]

### Design Principles
[One line each for separation of concerns, programming by intention, encapsulation, high cohesion, low coupling: OK, or the violation with file:line.]

### Executed
[What the reviewers actually ran, against head and base. Green tests alone are not evidence.]

End with exactly one line: `VERDICT: APPROVE` when Act On is empty, otherwise `VERDICT: CHANGES`.
