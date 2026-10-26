---
description: how names and types interact; a named context
requires: [name, type, context, owns, watches]
---

# module

a module is a [[context]] with a [[name]]: the names and [[type]]s that
interact in it, and how they do. its [[state]] says what it [[owns]], what it
[[watches]], what it [[requires]] and what it [[provides]]. its [[text]] says
what it is for.

modules don't call each other. they meet in what one owns and another
watches:

- `log` owns `log.jsonl` and appends to it
- `hooks` watches `log.jsonl`, and owns `scripts/hooks/event.sh` and
  `scripts/event/hooks/<name>.sh`, one per event it handles

either side can be swapped without the other knowing, as long as the file
between them stays the same.
