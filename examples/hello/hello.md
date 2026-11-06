---
name: hello
description: write one fixed greeting
owns:
  - greeting.txt
writes:
  - greeting.txt
---

# hello

The smallest module that `src/core/run/argc.sh run` can execute: one command,
one owned output. `hello.sh` writes a fixed line to `$OUT/greeting.txt`. The
runner stages it, checks it against `owns`, and only then moves it to
`greeting.txt` beside this file. Running it twice changes nothing the second
time.
