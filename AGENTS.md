# sesgoe/pstack

A fork of pstack. `FORK.md` lists every local edit and the upstream sync steps; record each new edit there.

- Read and follow skills from this checkout's `skills/`, not `~/.claude/skills` or `~/.agents/skills`. The installed copy is pinned in agent-config's `skills.conf` and lags `main`.
- Run `scripts/check.sh` before committing. A script this fork adds under `skills/*/scripts/` ships with a `<name>.test.sh` beside it, which the check runs.
- A `.test.sh` sources `scripts/test-lib.sh` for `check` and `finish`. A check that a process stopped also asserts that it ran: `kill -0 ""` reads as stopped.
- To prove a test catches a bug, break a copy of the script and record the test's exit status beside its FAIL lines. No FAIL and exit 0 means the break never applied.

| Rule | Enforced by |
|---|---|
| `render-prompt` behaviour | `skills/interrogate/scripts/render-prompt.test.sh` |
| `run-codex-reviewer` behaviour | `skills/interrogate/scripts/run-codex-reviewer.test.sh` |
| A test that aborts says so | `scripts/test-lib.sh` ERR trap; `scripts/check.sh` names a test that exits nonzero |
| Shell scripts pass shellcheck | `scripts/check.sh` |

`scripts/check.sh` runs every row, locally and in CI.
