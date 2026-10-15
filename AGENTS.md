# sesgoe/pstack

A fork of pstack. `FORK.md` lists every local edit and the upstream sync steps; record each new edit there.

- Read and follow skills from this checkout's `skills/`, not `~/.claude/skills` or `~/.agents/skills`. The installed copy is pinned in agent-config's `skills.conf` and lags `main`.
- Run `scripts/check.sh` before committing. A script this fork adds under `skills/*/scripts/` ships with a `<name>.test.sh` beside it, which the check runs.

| Rule | Enforced by |
|---|---|
| `render-prompt` renders the whole diff from any cwd, takes excludes literally (non-ASCII, `./`, both rename sides), and ignores diff config | `skills/interrogate/scripts/render-prompt.test.sh`, via `scripts/check.sh` and CI |
| `run-codex-reviewer` renders before it creates the worktree, hands codex the prompt, model, and effort, and removes the worktree when codex exits or fails, and a SIGTERM stops codex too | `skills/interrogate/scripts/run-codex-reviewer.test.sh`, via `scripts/check.sh` and CI |
