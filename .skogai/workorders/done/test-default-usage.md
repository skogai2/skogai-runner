---
name: test-default-usage
description: mise run test runs the usage implementations; the frozen argc side moves to test:argc
reads: [mise.toml, tests/contract.bats, tests/run.bats, CLAUDE.md]
owns: [mise.toml]
---

# test-default-usage

## Intent

usage is the interface now and the argc files are frozen (decided 2026-11-06). The default check should test what we use. The argc side keeps a task of its own so it doesn't break without anyone noticing while it still exists.

## Deliverable

In `mise.toml`:

- `test` runs `bats tests` with `CONTRACT_IMPL=usage RUN_IMPL=usage`
- `test:argc` runs `bats tests/contract.bats tests/run.bats` with the default (argc) implementations
- `test:usage` is removed (it's now the same as `test`), or kept as an alias of `test`. Choose one and say which.
- `test:container` runs the usage implementations as well (pass the two variables with `-e`)
- every task that needs the image still depends on `image`

## Acceptance

```bash
mise run test
mise run test:argc
mise tasks
```

All three succeed (Podman-dependent cases may skip). `mise tasks` shows the new descriptions.

## Out of scope

Test files and `CLAUDE.md`. The lead updates the commands section in `CLAUDE.md` after it merges.

## Report back

The acceptance output and the final `[tasks]` section.
