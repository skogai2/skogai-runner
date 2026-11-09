---
title: Config moved out of core into an opt-in module backed by mise
author: Emil
date: 2026-11-09
standing: true
id: l-f2f92f7d
scope: repo
status: active
src: init-review
---

## Decided
- The team dropped the git-config layers and local override files. A module's env script only runs once the module is installed, so installing it is the opt-in.
- In the code: Don't reintroduce system/global/local git-config layers, module.local.md, --file/--scope or SKOGAI_SYSTEM_DIR. Layering uses mise with MISE_OVERRIDE_CONFIG_FILENAMES. A module's `env:` script runs only for installed modules.

_From PR #1 here, Oct 27._
