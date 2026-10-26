---
description: how names and types interact; a named context
requires: [name, type, context, owns, writes, watches]
---

# module

a module is a [[context]] with a [[name]]: the names and [[type]]s that
interact in it, and how they do. its [[state]] says what it [[owns]], what it
[[requires]] and what it [[provides]]. its [[text]] says what it is for.

modules never write each other's files. they interact in three ways:

- **owns**: `log` owns `log.jsonl` and the folder `logs/`
- **writes**: calling `bin/log` is the only way to log something
- **watches**: `hooks` adds `logs/event/hooks.sh`, and `log` calls it on
  every event it writes

that makes every module a publisher of what it owns and a possible subscriber
to everything else. either side can be swapped without the other knowing, as
long as the name and the folder between them stay the same.
