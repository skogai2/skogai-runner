---
name: contract-yq-flavor
description: the contract checker refuses a yq that is not mikefarah's instead of judging every file invalid-yaml
reads: [src/core/contract/argc.sh, tests/contract.bats, mise.toml, .harness/features.json]
owns: [src/core/contract/argc.sh, tests/contract.bats]
---

# contract-yq-flavor

## Intent

The checker exits 1 when `yq` is missing. When a different program named `yq` is first on `PATH`, for example the Python yq/jq wrapper Ubuntu ships as `/usr/bin/yq`, every file gets `{"verdict":"invalid","reasons":["invalid-yaml"]}` with exit 0. A wrong verdict that looks like a real answer is worse than a refusal, and it already happened: outside `mise exec`, five contract tests fail for this reason alone. Validate the tool before any verdict.

## Deliverable

- `check` exits 1, with empty stdout and a one-line diagnostic on stderr naming the problem, when `yq` is not mikefarah's yq v4 or newer. Pick a detection that a different yq cannot match by accident, such as parsing `yq --version`.
- A bats test that puts a fake `yq` first on `PATH` and asserts exit 1, empty stdout and the diagnostic. Follow the existing missing-tool test.
- The header comment of `argc.sh` documents the new exit-1 case.

## Acceptance

```bash
mise exec -- bats tests/contract.bats
mise exec -- bats tests
.harness/init.sh smoke_test
```

All three pass, and the new test fails if the detection is removed.

## Out of scope

- Checking jq's version.
- Changing any verdict rule or reason name.
- `.harness/features.json`. It belongs to the lead. Say in the report that F001's exit contract gained a case.

## Report back

The detection used and why it is reliable, the acceptance output, and the line the lead should add to F001.
