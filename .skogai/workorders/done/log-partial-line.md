---
name: log-partial-line
description: run/usage.sh ends a torn last line in the event log before appending, so one interrupted write never corrupts the next event
reads: [docs/evidence.md, src/core/run/usage.sh, tests/run-events.bats, .harness/context_summary.md]
owns: [src/core/run/usage.sh, tests/run-events.bats, docs/evidence.md]
---

# log-partial-line

## Intent

Plan step 3, first open item in `docs/evidence.md`: an interrupted write (killed runner, full disk) can leave the log's last line without its newline. Today the next run's first event is then glued onto that fragment, and *both* lines become unreadable. A torn line must stay one bad line, never two.

## Deliverable

In `src/core/run/usage.sh`, `_open_log` already proves the log takes an append before any effect. Extend it:

- When the log is non-empty and its last byte is not `\n`, append a single `\n` before anything else, and say `log had a partial last line, ended it: <file>` on stderr. The fragment itself is left as it is: the log is append-only, so the runner never rewrites or truncates it.
- When that append fails, it is the same failure as today: exit 1, `cannot append to log: <file>`, empty stdout, no effect.
- A log that is empty, missing, or already ends in `\n` is untouched apart from the events, as now. Repeating a run on a repaired log adds no second newline (idempotent).
- Use bash and the tools the runner already calls (`tail -c 1` is fine). No sed or awk. Stdout JSON and exit codes are unchanged.
- `docs/evidence.md`: move the partial-line half of "Append failure after an effect" out of **Open** into the described behavior, marked implemented and verified. The other half (an effect whose `apply`/`end` record failed to append) stays open.

## Acceptance

```bash
CONTRACT_IMPL=usage RUN_IMPL=usage mise exec -- bats tests/run-events.bats
CONTRACT_IMPL=usage RUN_IMPL=usage mise exec -- bats tests/run.bats   # unchanged behavior
.harness/init.sh smoke_test
```

New cases in `tests/run-events.bats` (isolate `HOME`, `XDG_STATE_HOME` and unset `SKOGAI_LOG`, like the existing ones). They use `check` so they don't need Podman:

- a log whose last line is a fragment (`{"ts":"2026`, no newline): after one `check`, the fragment is its own line, unchanged, every following line parses with `jq`, and stderr names the log
- the same log checked a second time gets no extra empty line
- a log that already ends in `\n`: no stderr note, and the bytes before the new events are identical

## Out of scope

`run/argc.sh` (frozen), the contract checker, a reader command (`log-reader` is a separate workorder), rotation, locking, and recovering an effect whose record failed to append.

## Report back

The acceptance output, the stderr line as it appears, and any decision this workorder didn't settle.
