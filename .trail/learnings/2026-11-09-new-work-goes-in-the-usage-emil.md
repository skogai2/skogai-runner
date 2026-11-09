---
title: New work goes in the usage-based scripts; the older argc ones are frozen
author: Emil
date: 2026-11-09
standing: true
id: l-5f7c12a6
scope: repo
status: active
src: init-review
---

## Decided
- The team picked usage plus mise as the interface. The argc implementations stay in the repo but get no new work.
- In the code: Put new code in src/core/main-usage.sh, src/core/contract/usage.sh, src/core/run/usage.sh, examples/usage/ and tests/fixtures/run-usage/. Do not extend the argc files. mise run test uses CONTRACT_IMPL=usage RUN_IMPL=usage.

_From PR #9 here, Nov 6._
