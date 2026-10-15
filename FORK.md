# sesgoe/pstack fork

A fork of [backnotprop/pstack](https://github.com/backnotprop/pstack) (itself a mirror of
`cursor/plugins/pstack`) with a few local edits. Installed for Claude Code and Codex by
`github.com/sesgoe/agent-config` (`skills.conf` pins a commit from this repo's `main`).

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
  - a fix-round series gets one last whole-series review before APPROVE, and a script that writes
    outside the worktree runs end to end in one named reviewer only (2026-10-13).
  - from a retro on a 19-round review loop (2026-10-13): the intent paragraph names the threat
    model, and a bypass that needs a client outside it is Noted; a second finding of one class in
    one unit brings a table or harness test into Act On; a "Shared Machine" section in
    `execute-and-probe.md` (namespaced probes, signal only your own PIDs, leave the author's
    ports, devices, and backends alone), required by the reviewer prompt; Claude Code reviewer
    worktrees are removed after the verdict.
  - `scripts/render-prompt` (2026-10-13): fills `references/reviewer-prompt.md` for one reviewer
    (intent, head SHA, the base...head diff with `--exclude` paths, the three lens references, and
    a `--runner` line for the Shared Machine rule) and prints the path of the written prompt.
    Step 3 renders every reviewer's prompt with it, the codex one included.
  - from a retro on the render-prompt session, whose loop ran 6 rounds (2026-10-13): the threat
    model also names the environment and what a failure costs, and findings outside it are Noted;
    new "Cost of a Fix" in `lead-judgment.md` (a fix costs the next round's review; narrow before
    adding; a specified pass-through interface keeps its semantics); Same Class Twice applies only
    inside the threat model; fix rounds review their fix commit and the whole series once, as the
    final gate; reviewers' scratch goes under their own `mktemp -d` with `TMPDIR`; a comparison
    counts only when both sides ran.
  - `scripts/run-codex-reviewer` (2026-10-15, agent-config #5): one call starts a `codex:` reviewer.
    It takes render-prompt's flags plus `--model` and `--effort`, renders the prompt, runs
    `codex exec` in a worktree beside it, and removes that worktree when codex exits. It replaced
    a multi-line SKILL.md block whose bugs took three review rounds. Round cleanup is a one-line loop
    in SKILL.md; a `cleanup-round` helper waits until that line gets mistyped.
  - when the reviewed repo isn't the session's repo, a Claude reviewer's worktree is made by hand
    at `<prompt dir>/wt`, so one cleanup loop over prompt dirs covers it and codex's (2026-10-15).

- `skills/poteto-mode`: a "The user approves each push" non-negotiable and a **PR hand-off** step
  in `playbooks/opening-a-pr.md`. When the user's instructions reserve that call, every playbook
  stops before the first push: commits on a branch, an `interrogate` review (repeated after each
  fix) ending in `VERDICT: APPROVE`, then a hand-off with the PR title and body that asks for the
  go-ahead. On the go-ahead the agent pushes and opens the PRs. Force-push, merge, and auto-merge
  need their own ask.
  - The PR body has a `## Risk Analysis` section after `## Blast Radius` (2026-10-10): the door
    and rollback, rollout order and failure window, failure modes, and mitigations taken or
    skipped. Blast Radius keeps only who and what the change touches.
  - `playbooks/authoring-a-skill.md` step 2 runs every changed shell block as written, under
    bash and zsh, success and failure (2026-10-13).

- `skills/pr-mode` (ours, 2026-10-10): the user's entry point for PR work. It runs `poteto-mode`
  and adds local triggers (`verify-this` for Verification claims, a recommended
  `thermo-nuclear-code-quality-review` on one-way doors, a stop-and-ask when the `interrogate`
  loop stops converging, and later-step findings going to the issue, 2026-10-13; the stop also counts
  rounds of mostly fallout or out-of-threat-model findings and a growing do-not-re-report list, and
  forecasts the next round's yield, 2026-10-13; Consider items are listed and offered as a follow-up
  issue before the hand-off closes the source issue, 2026-10-15). New workflow triggers go there, not
  into `poteto-mode`, so upstream merges stay small. The triggered skills come from Cursor's
  `cursor-team-kit`, which fleet installs.

- `skills/retro` (ours, 2026-10-10): the user's retrospective, a wrapper over `reflect` in the
  same shape as `pr-mode`. It replaces Matt Pocock's `/retro`. It appends retro's lenses
  (navigation, guardrails, steering bloat, tool economy, information access, repo lessons) to
  reflect's reviewer prompts, and routing overrides to its synthesizer: lessons can land in the
  repo's AGENTS.md or a doc, in the global AGENTS.md, or go to `correct` to become a check;
  the skill-was-used gate covers skill edits only; the backlog is listed, not filed.
  `reflect` itself is unchanged.

- `skills/writing-for-agents` (2026-10-10): copied unchanged from Matt Pocock's skills
  (github.com/mattpocock/skills, `skills/productivity/writing-for-agents` at `6fd9479`, MIT,
  license in the skill folder). pstack's `technical-writing` covers docs for people; this one
  covers text for an agent's context (AGENTS.md lines, skill descriptions). `retro` loads it.

- `AGENTS.md`, `scripts/check.sh`, and `.github/workflows/check.yml` (ours, 2026-10-13): the check
  runs every `skills/*/scripts/*.test.sh`, such as `render-prompt.test.sh`. Since 2026-10-15 the tests
  source `scripts/test-lib.sh` (a FAIL line when a test aborts), and the check also runs shellcheck.

## Syncing with upstream

```sh
jj git fetch --remote upstream      # or: git fetch upstream
jj new main upstream/main -m "Merge upstream pstack"   # or: git merge upstream/main
# resolve conflicts in the files listed above, then push main and bump the pin in agent-config
```
