---
description: the value a key has when nothing says otherwise
requires: [state]
---

# default

every key in [[state]] has a default. it is the base, the one that
[[layer]]s are applied on top of.

because a key with no default can't be read, a thing that introduces a key
also gives it a default.
