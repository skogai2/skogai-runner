---
description: a named function in three steps; interface, validate, then a black box that returns a string
requires: [name, interface, validate]
---

# command

a command is the named function a module offers, and the only way to act on
what it [[owns]] (see [[writes]]). it's written in three steps:

1. **[[interface]]**: the types of its input and output
2. **[[validate]]**: check and transform the input into exactly those types
3. **body**: a black box that gets the validated input and returns a string
   if it succeeds, or an error if it doesn't

the body never sees anything but its validated input and its [[context]].
that keeps it sandboxed from the first step to the last: what goes in has
already been checked, and what comes out is either the promised string or an
error.

because steps 1 and 2 hold all the knowledge about input, the body can be
anything, and swapping it keeps the command.
