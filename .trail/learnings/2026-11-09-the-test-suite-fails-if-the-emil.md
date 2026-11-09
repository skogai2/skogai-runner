---
title: The test suite fails if the open workorder queue breaks the contract rules
author: Emil
date: 2026-11-09
standing: true
id: l-fcd54f88
scope: repo
status: active
src: init-review
---

## Decided
- Two open workorders owning the same path would break parallel handoff. A bats test now runs the checker over the queue so conflicts show up in CI.
- In the code: tests/workorders.bats runs the contract checker over .skogai/workorders/open/*.md from the repo root and expects every verdict to be valid. It skips if open/ is empty, because the checker exits 2 with no arguments.

_From PR #5 here, Nov 5._
