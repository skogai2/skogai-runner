---
title: Workorder file ownership allows directories again; the files-only rule was reverted
author: Emil
date: 2026-11-09
standing: true
id: l-514dfd20
scope: repo
status: active
src: init-review
touches:
  - ".skogai/workorders/WORKORDERS.md"
---

## Tried and ruled out
- A files-only ownership rule was added, then undone at the maintainer's request. The overlap gap (a directory and a file inside it both pass) is known but no longer documented.
- In the code: In .skogai/workorders/WORKORDERS.md, `owns` lists paths the agent may create or change, files or directories. Don't re-add the 'individual files only' rule or the Directory overlap decision. The checker's ownership-conflict rule does not catch a directory plus a file inside it.

_From PR #11 here, Nov 8._
