---
name: readme-demo
description: the README's try-it block runs as written from a fresh checkout
reads: [README.md, src/core/main.sh, tests/main.bats, docs/runner.md]
owns: [README.md, examples/hello.sh]
---

# readme-demo

## Intent

The "Try it from the checkout" block in `README.md` registers `scripts/memory.sh`, which does not exist. A newcomer's first command fails. The demo should run when pasted into a shell from the repo root.

## Deliverable

- One small argc script, `examples/hello.sh`, that the README block registers. It has a `@describe`, at least one subcommand with an argument, and effects limited to printing to stdout. It doesn't have to be memory-themed. If it is, say plainly that it is a stub.
- The README block and the sentence after it updated to match the script and its commands. Nothing else in the README changes.

## Acceptance

From the repo root, in a fresh `bash` with the mise tools on `PATH` (for example via `mise exec -- bash`), paste the README block exactly as written. Every command exits 0, and `ls` lists the registered example. Then:

```bash
mise exec -- argc --argc-export examples/hello.sh >/dev/null
mise exec -- bats tests
.harness/init.sh smoke_test
```

## Out of scope

- Changes to `src/core/main.sh` or the tests.
- The CLAUDE.md note about the missing script. The lead removes it after merge.

## Report back

The pasted README block and its output, and the acceptance output.
