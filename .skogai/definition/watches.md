---
description: the paths a module reads and reacts to when they change
requires: [name, state, module]
---

# watches

`watches` is a [[state]] key that lists paths. when a watched path changes,
the [[module]] reacts. a module reading another one's output is the only way
modules interact, and watching is how that reading happens.

what a module watches is part of its input, along with everything in its
[[context]].
