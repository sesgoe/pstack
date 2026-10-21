---
name: interrogate
description: "Use for \"interrogate\", \"adversarial review\", \"multi-model review\", \"challenge this\", \"stress test this code\", \"find blind spots\", or \"tear this apart\", and for every code review of a branch, PR, or fix commit. Multiple LLM reviewers challenge changes from independent angles, executing the code rather than only reading it."
---

# Interrogate

Spawn one reviewer per configured model to adversarially review code changes. The adversarial signal comes from model diversity, not assigned personas. The deliverable is a synthesized verdict. Do NOT auto-apply changes.

## Step 1, Scope

Identify what to review from context:

- If the user points at specific files or a diff, use that.
- If on a feature branch, the scope is `main...HEAD` (or the appropriate base branch): `--base` and `--head` for `render-prompt` in Step 3.
- If the user's message references recent work, gather the relevant files.
- A fix commit made in response to an earlier review is its own scope and gets its own review. Fixes create bugs.
- Before `VERDICT: APPROVE` on a change that took more than one fix round, review the whole series against the base once, as the final gate. Each earlier fix round reviews only its own fix commit. A series-pass finding that isn't a regression from the fixes goes to Consider.

Reviewers are fresh subagents that did not write the code. The author's own pass over its work is a checklist pass, not a review.

`render-prompt` packages the diff. Reviewers read surrounding files in their own worktree.

## Step 2, Intent

Before spawning reviewers, state the intent in one clear paragraph from the user's message, commit messages, the PR description if one exists, and the code. If you're unsure about the intent, ask the user before proceeding.

The paragraph names the threat model: who sends the traffic or calls the code, what that client actually sends, the environment it runs in (config, filenames, locale), and what a failure costs. A finding that needs a client, input, or environment outside it goes under Noted.

It also names the thing the user will touch: the link they click, the page, the command, and the client that opens it. Reviewers check that thing where it is used, not only where the code stores or builds it (a link Linear stored fine that T3 couldn't open passed six rounds).

## Step 3, Spawn Reviewers

Launch all reviewers in a single message with the Task tool, one per entry on the `interrogate reviewers` line in the pstack settings file (`~/.cursor/rules/pstack-models.mdc` in Cursor, `~/.agents/pstack-models.md` in other harnesses), labeled Reviewer A, B, and so on to match the entry count. If the file or that line is missing, use the table defaults.

**Other harnesses.** The spawns in this skill use Cursor's `Task` tool. In another harness, use its subagent tool: `Agent` in Claude Code (`subagent_type: general-purpose`), `task` in OpenCode (`subagent_type: general`), `spawn_agent` in Codex. Keep the prompt and the model. Drop parameters your tool doesn't have. If your harness has no subagent tool, as in Pi without an extension, run each reviewer yourself, one after another.

| Subagent | Default model |
|----------|---------------|
| Reviewer A | `claude-opus-5-5-xhigh` |
| Reviewer B | `grok-4.7-xhigh-fast` |

Each reviewer gets `subagent_type: generalPurpose` and `model` set to its configured entry, or its table default when there is no configured line. Omit `model` for an `auto` or `inherit-parent` entry, so that reviewer runs on the parent model.

Every reviewer runs in its own git worktree, so it can't touch the author's tree. In Claude Code, pass `isolation: "worktree"`. That worktree starts at the remote's default branch, not the reviewed commit, and the prompt's first step checks out `{HEAD_SHA}`. A `codex:` entry gets its worktree from the steps below. When the reviewed repo isn't your session's repo, `isolation: "worktree"` cuts its worktree from the wrong repo. In that case, or in a harness with neither, prepare each reviewer with `prepare-reviewer` (below) and start its prompt with `Work only in <wt>: cd there first.`, naming the printed `wt=`. Keep your harness's isolation all the same: the unused worktree is a throwaway in case the reviewer skips the `cd`. `prepare-reviewer` is the one source of a reviewer worktree outside your harness's own isolation. Where your tool has a `readonly` flag, leave it off so reviewers can run code.

A worktree doesn't contain a script that writes outside it (to another host, or to a path in the user's home or on a Windows drive). When the change has one, render one reviewer's prompt with `--runner <script>` to name it that script's runner; the others run its pieces.

Render each reviewer's prompt with one call from anywhere in the reviewed repo, where `<skill>` is this skill's directory:

```sh
<skill>/scripts/render-prompt --head <sha> --base <ref> [--exclude <path>]... [--runner <script>] --intent - <<'EOF'
<Step 2 paragraph>
EOF
```

It fills `references/reviewer-prompt.md` with the intent, the full head SHA, the `<base>...<head>` diff (minus each `--exclude` path, given from the repo root, such as `flake.lock`; an exclude that matches no changed path is an error; exclude both sides of a rename, or its directory, since one side alone shows the other as a whole added or deleted file), and the rubric, code-quality, and execute-and-probe references, so every model applies all three lenses. It writes `prompt.md` into a fresh temp directory and prints that path. The quoted heredoc keeps the shell from expanding backticks or `$` in the paragraph. Every subagent reviewer's whole prompt, in any harness, is `Read <path> in full and follow it.`, after the `Work only in` line for a reviewer from `prepare-reviewer`. A scope that isn't a diff (files the user points at) still gets the template filled by hand: the intent as a blockquote, and `{RUNNER}` empty unless that reviewer is the runner. Render every subagent reviewer's prompt first, then send the codex background call and the subagent spawns in one message.

A reviewer that needs its own worktree (see above) gets `prepare-reviewer` in place of `render-prompt`, with the same flags, run from the reviewed repo's git checkout (from a jj workspace, its colocated main checkout):

```sh
<skill>/scripts/prepare-reviewer --head <sha> --base <ref> [--exclude <path>]... [--runner <script>] --intent - <<'EOF'
<Step 2 paragraph>
EOF
```

It resolves `--head` once, renders the prompt, adds a detached worktree at that full SHA in `<prompt dir>/wt`, and prints `prompt=<path> wt=<path>`. A failure or a signal leaves neither behind (unless its launcher started that signal ignored); fix its input and run it again. The cleanup loop below removes the worktree with its prompt dir.

**`codex:<model>` entries** (for example `codex:gpt-6-astra`) run that reviewer through the Codex CLI instead of your subagent tool, so a Claude-led review still gets an OpenAI reviewer. The panel crosses vendors to cover blind spots from one lab's training. For each such entry:

1. In one background call (in Claude Code, `Bash` with `run_in_background`; you are notified when it exits), run `run-codex-reviewer` with the `render-prompt` flags and `--intent` heredoc from above:

```sh
<skill>/scripts/run-codex-reviewer --model <model> --effort <effort> <render-prompt flags>
```

   `<effort>` is the effort in the settings file's `# budget` line (for example `high`), or `high` without one. The script renders the prompt, prints `prompt=<path> out=<path>`, runs `codex exec` in a worktree at `<head>` beside the prompt, and removes that worktree when codex exits. The reviewer has full, unsandboxed access, including the network, so it can install and run anything. A failed render creates nothing; fix its input and run the call again.
2. Spawn the other reviewers in the same message. When the command exits, read the printed `out=` file as that reviewer's result. To retry a failed codex run, run the same call again.

**In T3** (the `delegate_task` tool from the `t3-code` MCP server is present), every reviewer, `codex:` entries included, runs as a T3 child task instead, so the user can see the panel in T3, read each transcript, and cancel a reviewer with `task_cancel`. Call `orchestrator_capabilities` once for the provider and model ids. Render every prompt with `render-prompt` (no `run-codex-reviewer`), then send one `delegate_task` per reviewer in one message:

- `target`: a `codex:<model>` entry is provider `codex`, model `<model>`, option `reasoningEffort` set to the budget-line effort (or `high`). Any other entry is the provider and model id from `orchestrator_capabilities` that matches it (an alias like `opus` is that family's newest id), with its effort suffix (`-xhigh`) as the `effort` option. Omit `model` for an `auto` or `inherit-parent` entry.
- `isolation: "worktree"`, `role: "review"`, `mode: "async"`, and a `title` and `clientRequestId` naming the round and the reviewer (`round 2, Reviewer B`). T3 can name the child's branch after its title (one trial child got `ses/review-task`), so keep titles distinct.
- `task`: `Read <path> in full and follow it.` The child's worktree is cut from your thread's local commit and the prompt checks out `{HEAD_SHA}`. When the reviewed repo isn't your thread's repo, prepare each reviewer with `prepare-reviewer` and start its task with the `Work only in` line, as above, keeping `isolation: "worktree"`.

Each child wakes your thread when it finishes; its `task_status` `summary` is that reviewer's result. To retry a failed reviewer, send a new `delegate_task` with a new `clientRequestId`. If `delegate_task` rejects a reviewer (its provider is disabled), run that reviewer the non-T3 way above and say so under **Reviewers**. Child threads don't show in the sidebar, but archiving one leaves its worktree and branch in place, so the cleanup below covers them.

**After the verdict**, remove the Claude Code reviewers' worktrees and this round's prompt directories. `isolation: "worktree"` leaves each reviewer's worktree, locked, under the main checkout's `.claude/worktrees/agent-<id>` on a `worktree-agent-<id>` branch. From the main checkout of your session's repo, the one those worktrees were cut from (in a cross-repo review, not the reviewed repo), with every agent id and the directory of every prompt path printed this round (skip the first line when no reviewer used `isolation: "worktree"`; the second line works from any directory):

```sh
for id in <agent-id>...; do git worktree remove -f -f .claude/worktrees/agent-$id && git branch -D worktree-agent-$id; done
for d in <prompt dir>...; do [ ! -d "$d/wt" ] || git -C "$d/wt" worktree remove -f -f "$d/wt"; rm -rf "$d"; done
```

For each T3 child task, read its `worktreePath` and `branch` with `t3_thread_read` on its `childThreadId`, archive it (`t3_thread_organize` `archive`), then from the main checkout of your thread's repo, the one the child's worktree was cut from (in a cross-repo review, not the reviewed repo), run `git worktree remove -f -f <worktreePath> && git branch -D <branch>`.

If `codex` is missing or the run fails, retry once. Never substitute a model from the parent's vendor. Name the failure under **Reviewers**. The verdict can't be `VERDICT: APPROVE` until a codex reviewer has run.

If your subagent tool rejects a configured entry, run that reviewer on its family's table default and say so. Families go by prefix: `claude-*` and `grok-*`. With no family match, use Reviewer A's default. If it rejects a table default, spawn with the closest equivalent from the valid slugs in its error message or your harness's model list (prefer the same family and reasoning tier), and open a separate PR to update the default table. Do not block the review on the slug issue. Never treat an alias entry as a rejected slug or apply either fallback to it.

## Step 4, Synthesize

As results come back, build a unified picture. Parse every reviewer's findings. Merge findings that describe the same issue differently, and note which models raised each one. Findings two or more models raised independently are the highest signal. Read a lone model's finding, but weight it accordingly. Note disagreements. If one model flags something and another explicitly says the opposite, that is context for the verdict.

## Step 5, Lead Judgment

You are the lead reviewer, a pragmatic senior engineer, not a neutral aggregator. Read `references/lead-judgment.md` for the full framework. Put every finding in one of four buckets, with the model(s) that raised it and a one-line rationale.

- **Act on**. Real issues affecting correctness, security, or maintainability given the actual goals. They would block a real PR.
- **Consider**. Legitimate, but you're not sure they outweigh the cost of addressing them now. Worth the user's attention.
- **Noted**. Technically valid but not actionable. Context-dependent, premature optimization, or low-impact at this stage.
- **Dismissed**. Wrong, nitpicky, or missing context, with a brief reason.

Before an edge-case finding goes in Act On, count how often its starting condition occurs in live data. At zero, offer leaving the case out, stated in the code or docs, as the fix: patching each rare case makes the next round find bugs in the patches.

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
[What the reviewers actually ran, against head and base. Green tests alone are not evidence. Say whether anyone checked the thing the user will touch (Step 2), or mark it unverified.]

End with exactly one line: `VERDICT: APPROVE` when Act On is empty, otherwise `VERDICT: CHANGES`.
