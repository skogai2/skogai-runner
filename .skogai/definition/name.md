---
description: one lowercase segment; a name is a file
requires: []
---

# name

a name is a [[file]]. it's one lowercase segment: `.` (in keys), `_` (in
env) and `/` (in paths) mean a relation, so they never appear inside a name.
`foo-bar` under `my` is `my.foobar`.

the folders above a name aren't part of it. they are its [[type]] and its
relations. because the file is the name, it doesn't need to be stated in
[[state]]: the name key defaults to the filename.
