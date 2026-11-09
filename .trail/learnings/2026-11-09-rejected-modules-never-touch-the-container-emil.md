---
title: "Rejected modules never touch the container runtime, so tests can use a fake"
author: Emil
date: 2026-11-09
standing: true
id: l-848392c4
scope: repo
status: active
src: init-sessions
---

## Decided
- The module check runs first and needs only a few light tools. Podman and the image are only checked afterwards, so tests can swap in a fake podman and prove that a rejected module never reaches it.
- In the code: In `src/core/run/argc.sh`, `check` needs only argc, jq and yq. Podman and image checks happen only in `run`, after `check` passes. Check tools first (exit 1), then arguments (exit 2). Keep this order so the fake-`podman` test stays valid.

_From past Claude sessions here, Nov 6._
