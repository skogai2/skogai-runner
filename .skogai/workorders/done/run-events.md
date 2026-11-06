---
name: run-events
description: run/usage.sh appends one JSONL event per step of a check or run, in the skogai-core log envelope
reads: [docs/plan.md, src/core/run/usage.sh, tests/run.bats, examples/usage/hello/hello.md, .harness/context_summary.md]
owns: [src/core/run/usage.sh, tests/run-events.bats, docs/evidence.md]
---

# run-events

## Intent

Plan step 3: a failed or successful run must be explainable from its record alone. Start from the shape skogai already writes in its hook log (`/home/skogix/skogai/.skogai/logs/skogai-core/log.jsonl`), where each line is `{ts, event, action?, input}`: `event` says what happened, `action` is a short human summary of the effect, `input` is the raw payload. Extend that envelope rather than inventing a new one.

## Deliverable

`src/core/run/usage.sh` appends events to a log file while it works. Its stdout JSON and exit codes stay exactly as they are now.

- A new global flag `--log <file>` (env `SKOGAI_LOG`) names the log file. Default is `${XDG_STATE_HOME:-$HOME/.local/state}/skogai/run.jsonl`. The runner creates the parent directory and only ever appends to the file. The log is the runner's own output, not the module's, so it is never inside the module dir unless the caller puts it there.
- Every line has `ts` (UTC, ISO 8601 with milliseconds, like skogai-core), `event`, `input`, and also:
  - `id`: unique per event
  - `run`: one id shared by every event of the same invocation
  - `module`: the module name, plus `revision`, the sha256 of the `.md` and `.sh` content (so a log line names exactly what ran)
  - `outcome`: `ok`, `rejected`, `failed` or `unchanged`, depending on the event
  - `action` only when there was an effect (for example `applied greeting.txt`)
- Events: `check` (verdict and reasons), `exec` (container exit code; for `run` only), one `apply` per staged path (applied, unchanged or rejected with the reason), and a final `end` with the same verdict that went to stdout. A rejected check writes `check` and `end` and nothing else.
- No credentials or environment dumps in `input`. Paths are relative to the module dir.
- If the log can't be appended to, `run` stops with exit 1 **before** any effect. `check` does the same.
- `docs/evidence.md`: the event shape, one example log for a successful run and one for a rejected run, and which questions stay open (see Out of scope). Mark what is implemented and what is verified.

## Acceptance

```bash
mise exec -- bats tests/run-events.bats
CONTRACT_IMPL=usage RUN_IMPL=usage mise exec -- bats tests/run.bats   # unchanged behavior
.harness/init.sh smoke_test
```

`tests/run-events.bats` isolates `HOME`, `XDG_STATE_HOME` and `SKOGAI_LOG` under `$BATS_TEST_TMPDIR`, and shows:

- run `examples/usage/hello` (in a temp copy) twice: the first `end` is `applied`, the second `unchanged`, each run has its own `run` id, and the file grew without earlier lines changing
- a fixture from `tests/fixtures/run-usage/` that is rejected at check time logs `check` and `end` only
- the `fails` and `outside` fixtures can be explained from the log alone (exit code, rejected path)
- an unwritable log stops the run with exit 1 and leaves the module dir untouched

Podman-dependent cases skip without Podman, like `tests/run.bats`.

## Out of scope

`run/argc.sh` (frozen), the contract checker, examples and fixtures. Rotation, a reader or summary command, recovery after an interrupted write, and connecting events to a workorder id: write these down in `docs/evidence.md` as open, but don't build them.

## Report back

The acceptance output, one real log from the hello double-run, and every decision you made that this workorder didn't settle.
