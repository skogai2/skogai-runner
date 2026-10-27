---
type: module
name: test
description: run modules' tests with bats, what they require first, each in an empty sandbox
command: argc.sh
tools: [bats, yq]
requires: [core, sandbox]
files:
  - helper.bash
config: {}
---

# test

a module is tested after everything it requires, and only if that passed:
`skogai test run config` tests core, then config. a module whose
requirement failed is skipped, and the run fails. every test stands on an
empty sandbox, so a run whose sandbox can't be made stops before any test
(exit 2) instead of failing whatever comes first.

| command | |
|---|---|
| `run [name]... [--only] [--filter]` | the tests of each module and of what it requires, in closure order; `--only` drops what it requires |
| `closure [name]...` | that order, one name per line |

each module runs core's `tests/contract.bats` (what every module is held
to), the `tests/contract.bats` of each module it requires, then its own
`tests/*.bats`.

`helper.bash` is the base every test loads: `load "$SKOGAI_TEST_HELPER"`.
each test gets an empty sandbox (`skogai sandbox new --empty`) as its global
and local layers, and its repo as cwd, so nothing outside `BATS_TEST_TMPDIR`
is read or written. it is offered, so an installed test keeps it.
