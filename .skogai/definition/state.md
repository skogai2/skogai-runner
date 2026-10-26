---
description: key-value data; the frontmatter of a file
requires: [file, default]
---

# state

state is key-value data. a key is a [[name]] and a value is a scalar, a
list or more keys. `.` between names is a relation: `core.module.install`
is the key `install` under `module` under `core`.

state is data, not prose. what it means belongs in [[text]]. every key has a
[[default]], so a state can always be read as a diff on its default.
