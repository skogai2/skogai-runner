---
description: what a command gives back; always a string, with messages kept apart from it
requires: [command]
---

# output

a [[command]] always gives back a string. that string is its value, the one
thing a caller reads and passes on. when there is nothing to give, it's an
empty string, never a missing one.

anything said about the run (a rejection, a warning, progress) goes on a
second channel, next to the value and never inside it. the value stays
clean enough to pass straight to the next command.

a rejected input is a normal answer: an empty value and a message. a run
ends as failed only when something unexpected happens, not because the
input was wrong. and the answer never depends on hidden state, so a
rejection says nothing about what exists.
