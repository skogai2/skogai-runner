---
name: log-reader
description: a read-only usage script that summarises the run event log per run and shows one run's events
reads: [docs/evidence.md, src/core/run/usage.sh, src/core/contract/usage.sh, tests/run-events.bats, .harness/context_summary.md]
owns: [src/core/log/usage.sh, tests/log.bats, tests/fixtures/log/run.jsonl]
---

# log-reader

## Intent

Plan step 3: a run must be explainable from its record alone. The record exists (`docs/evidence.md`), but the only reader is a hand-written `jq` line. Give people and agents a read-only command that answers "what runs happened, and how did each end?" and "what exactly happened in run X?", from the log alone.

## Deliverable

`src/core/log/usage.sh`, a usage script (`#USAGE` spec, `usage bash` shebang, `case "$usage_cmd"` dispatch, like `src/core/contract/usage.sh`). Tools: bash and jq only.

- Global flag `--log <file>` (env `SKOGAI_LOG`), with the runner's default: `${XDG_STATE_HOME:-$HOME/.local/state}/skogai/run.jsonl`, treating an empty `XDG_STATE_HOME` as unset.
- Both commands declare `effect="read"` and never write anything, the log included.
- `runs`: one compact JSON object per run on stdout, in the order each run's first event appears: `{run, module, revision, started, ended, outcome, verdict, changed}`. `started` is the first event's `ts`. `ended`, `outcome`, `verdict` (`input.verdict`) and `changed` (`input.changed`, or `[]`) come from the run's `end` event. A run without an `end` event (interrupted) has `ended`, `outcome` and `verdict` as `null`. That is the point: it shows up, it isn't dropped.
- `show <run>`: that run's events, as they are in the log, one per line, in log order. `<run>` is a full run id or a unique prefix of one.
- Lines that are not JSON objects, or lack a string `run`, are skipped. stderr then says `skipped <n> unreadable lines: <file>`. Exit stays 0: the readable part is still an answer.
- Exit codes: 0 answered (an empty or missing log is an empty answer); 1 `jq` missing; 2 bad arguments, including `show` of an unknown run (`no such run: <id>`) or an ambiguous prefix (`ambiguous run: <prefix>`).
- The `#USAGE` `long_about` documents the output shape and the exit codes. `docs/evidence.md` is owned by another workorder, so the lead adds the pointer at merge.

## Acceptance

```bash
mise exec -- usage lint src/core/log/usage.sh
mise exec -- bats tests/log.bats
.harness/init.sh smoke_test
```

`tests/fixtures/log/run.jsonl` is hand-written in the shape `docs/evidence.md` documents (you can copy its examples). It contains: a run applied then a repeat that is unchanged, a rejected run, one run with no `end` event, and one unreadable line (a torn fragment). `tests/log.bats` isolates `HOME`, `XDG_STATE_HOME` and unsets `SKOGAI_LOG`, and shows:

- `runs` on the fixture: exactly one object per run in first-seen order, the interrupted run with `null` outcome, stderr counting the one skipped line, exit 0
- `show` with a full id and with a unique prefix print only that run's lines, byte-identical to the log; unknown id and ambiguous prefix exit 2
- a missing log: empty stdout, exit 0, and the file is still missing afterwards
- the default path follows `XDG_STATE_HOME`, and `--log` and `SKOGAI_LOG` override it
- running either command leaves the log's bytes unchanged

## Out of scope

Changing `src/core/run/usage.sh` or the event shape, writing to the log, registering the script with `skogai`, rotation, and linking runs to workorders or commits.

## Report back

The acceptance output, `runs` printed against the fixture, and any decision this workorder didn't settle.
