---
title: The contract checker must refuse a wrong yq instead of calling every file invalid
author: Emil
date: 2026-11-09
standing: true
id: l-2ddd3607
scope: repo
status: active
src: init-review
---

## Watch out
- A different yq made every file come back invalid-yaml with exit 0. That wrong verdict looked like a real answer.
- In the code: src/core/contract/argc.sh check requires mikefarah/yq v4 or newer. Otherwise it exits 1 with empty stdout and a one-line stderr 'wrong yq: need mikefarah/yq v4 or newer'. Tests in tests/contract.bats put a fake yq first on PATH.

_From PR #4 here, Nov 5._
