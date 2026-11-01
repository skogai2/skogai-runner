---
name: queue-check-test
description: the bats suite fails when the open workorder queue does not pass the contract checker
reads: [.skogai/workorders/WORKORDERS.md, src/core/contract/argc.sh, tests/contract.bats]
owns: [tests/workorders.bats]
---

# queue-check-test

## Intent

Parallel delegation is only safe while no two open workorders own the same path and each is well-formed. `WORKORDERS.md` asks the lead to run the checker by hand. Put that check in `mise run test` so a bad queue can't be committed unnoticed.

## Deliverable

`tests/workorders.bats`, which:

- runs `src/core/contract/argc.sh check` over `.skogai/workorders/open/*.md` from the repo root and asserts exit 0 and that every verdict is `valid`. On failure it prints the non-valid lines.
- skips with a clear message when `open/` has no `.md` files, because an empty queue is normal and the checker treats no arguments as exit 2.
- isolates `HOME` under `$BATS_TEST_TMPDIR` like the other suites.

## Acceptance

```bash
mise exec -- bats tests/workorders.bats      # passes on the current queue
mise exec -- bats tests
```

Then show the test catching a conflict. In a scratch copy (or temporarily, without committing it), add a second open workorder that owns `docs/runner.md`. The test should fail and name `ownership-conflict`. Remove the scratch file afterwards.

## Out of scope

Changing the checker, the existing suites, or any workorder file.

## Report back

The acceptance output, including the failing run.
