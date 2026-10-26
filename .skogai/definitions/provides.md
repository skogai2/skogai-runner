---
description: the names a thing stands in for; a virtual name
requires: [name, state, definition]
---

# provides

`provides` is a [[state]] key that lists [[name]]s. a thing that provides a
name can be used wherever that name is required.

this connects the three levels:

- the idea: a [[definition]], what `memory` means
- the contract: an [[interface]], what `memory` takes and returns
- the implementation: whatever `provides: [memory]`

any number of things can provide the same name, and swapping one for another
keeps the name. [[resolve]] picks which one is used.
