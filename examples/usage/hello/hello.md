---
name: hello
description: write one fixed greeting
owns:
  - greeting.txt
writes:
  - greeting.txt
---

# hello (usage)

The usage twin of [examples/hello](../../hello/hello.md), for
`src/core/run/usage.sh`. Same declaration, same output; only the command is
written for usage instead of argc.

`hello.sh` declares its input as a required `--out` flag that falls back to
`$OUT`, which is where the runner tells a module to stage its files. Run on its
own without `OUT`, it stops with `Missing required flag: --out <out>`:

```console
$ examples/usage/hello/hello.sh --help
$ OUT=/tmp examples/usage/hello/hello.sh            # writes /tmp/greeting.txt
$ src/core/run/usage.sh check examples/usage/hello/hello.md
$ src/core/run/usage.sh run examples/usage/hello/hello.md
```

The runner stages the file, checks it against `owns`, and only then moves it
to `greeting.txt` beside this file. Running it twice changes nothing the
second time.
