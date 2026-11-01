---
name: runner-doc-refs
description: docs/runner.md describes only what is in this checkout
reads: [docs/runner.md, src/core/main.sh, src/core/contract/argc.sh, tests/main.bats, tests/contract.bats]
owns: [docs/runner.md]
---

# runner-doc-refs

## Intent

`docs/runner.md` mentions `skogai-bridge-caller.sh` and `agents/demo/README.md`. Neither is in the checkout, so the link is broken. It also names `tests/main.bats` as "the current test suite", although `tests/contract.bats` exists too. Documentation must keep intended, implemented and verified behavior apart (`AGENTS.md`), and this page currently describes files that aren't there.

## Deliverable

- The bridge-caller and demo-agent paragraph either removed, or reduced to one sentence saying that the earlier bridge demo is not part of this checkout, with no dead link.
- The test paragraph names both suites in one or two sentences each: what `main.bats` covers, and that `contract.bats` covers `src/core/contract/argc.sh`.
- Every relative link left in the page resolves to an existing file.

## Acceptance

```bash
grep -oE '\]\([^)#]+' docs/runner.md | cut -c3- | grep -v '^https\?:' |
  while read -r p; do [ -e "docs/$p" ] || echo "dead: $p"; done   # prints nothing
grep -nE 'bridge-caller|agents/demo' docs/runner.md               # nothing, or only the one-sentence note
```

## Out of scope

Other pages, even ones with the same problem. List them in the report instead.

## Report back

The diff summary, the link-check output, and any other pages with dead references.
