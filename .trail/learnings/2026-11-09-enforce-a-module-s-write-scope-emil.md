---
title: "Enforce a module's write scope with a read-only container and staged output"
author: Emil
date: 2026-11-09
standing: true
id: l-89dfe2c6
scope: repo
status: active
src: init-sessions
---

## Decided
- The rules say forbidden writes must be impossible through filesystem access, not just flagged afterwards. The chosen design mounts the repo read-only plus one empty output folder, then checks that folder only holds allowed paths before moving files into place.
- In the code: Workorder commands run in Podman with the repo mounted read-only (as `mise run test:container` does) plus an empty writable output dir. The runner verifies output paths against `owns`, then moves them in one step. If anything is outside `owns`, reject it before changing anything outside the container. See `src/core/run/argc.sh`.

_From past Claude sessions here, Nov 6._
