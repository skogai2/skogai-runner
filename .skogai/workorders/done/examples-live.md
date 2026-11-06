---
name: examples-live
description: every usage example module is a live test, checked and run twice through run/usage.sh
reads: [examples/usage/hello/hello.md, examples/usage/hello/hello.sh, src/core/run/usage.sh, tests/run.bats]
owns: [tests/examples.bats]
---

# examples-live

## Intent

Each behavior the runner promises should have a small hello-world module under `examples/usage/` that anyone can run by hand, and the suite should prove each one still does what its Markdown says. Then adding a new example is how a new behavior gets tested live: no new test code needed.

## Deliverable

`tests/examples.bats`, which finds every `examples/usage/<name>/<name>.md` and, for each, in a temp copy of that directory:

- `src/core/run/usage.sh check` reports `valid`
- `run` reports `applied`, and every path in its `owns` now exists
- a second `run` reports `unchanged`, and the files are byte-identical

Generate one test per example (for example with `bats_test_function`, or a loop that prints which example failed), so a failure names the example. Isolate `HOME` like the other suites and capture `XDG_DATA_HOME` first (see the gotcha in `.harness/context_summary.md`). Skip the run cases without Podman or the `skogai-runner-dev` image, and keep the `check` case.

## Acceptance

```bash
mise exec -- bats tests/examples.bats
mise exec -- bats tests
```

Then show that a new example is picked up without editing the test: in a scratch copy, add `examples/usage/hello2/` (copy hello, rename the files and `name`), run the test and see it listed. Don't commit it.

## Out of scope

Changing the examples, the runner, or adding new examples. Examples that should *fail* (rejected, failing command) are fixtures under `tests/fixtures/run-usage/`, not examples.

## Report back

The acceptance output, including the scratch run with `hello2`.
