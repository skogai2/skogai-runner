---
title: "Every usage example doubles as a live test, so examples must be repeatable"
author: Emil
date: 2026-11-09
standing: true
id: l-8de053a9
scope: repo
status: active
src: init-review
---

## Decided
- Each example must pass check, apply on run, and report unchanged with identical file hashes on a second run. A new example is picked up with no test edit, and a non-idempotent one fails.
- In the code: tests/examples.bats generates tests from examples/usage/<name>/<name>.md. The run case needs podman and the skogai-runner-dev image, and skips without them. Make new examples idempotent.

_From PRs #9, #7 here, Nov 6._
