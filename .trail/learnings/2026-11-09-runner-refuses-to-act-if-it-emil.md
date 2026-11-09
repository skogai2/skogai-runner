---
title: Runner refuses to act if it cannot write its run log
author: Emil
date: 2026-11-09
standing: true
id: l-d5827dfa
scope: repo
status: active
src: init-review
---

## Decided
- The run log is evidence for what happened. Running with no way to record it would leave effects unexplained, so the runner fails first.
- In the code: src/core/run/usage.sh appends JSONL events to --log (env SKOGAI_LOG, default under XDG_STATE_HOME/skogai/run.jsonl). If the append fails it exits 1 before any check or effect. Stdout JSON and exit codes are otherwise unchanged. See docs/evidence.md.

_From PR #8 here, Nov 6._
