---
description: one lowercase segment that identifies a thing within its scope
requires: []
---

# name

a name is one lowercase segment. `.` (in keys) and `_` (in env) mean a
relation, so they never appear inside a name. `foo-bar` under `my` is
`my.foobar`.

a [[file]]'s name is its path, so it doesn't need to be stated in its
[[state]]: the name key defaults to the filename.

a path is a chain of names, one per [[folder]].
