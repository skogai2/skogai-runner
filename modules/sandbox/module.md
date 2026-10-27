---
type: module
name: sandbox
description: an empty skogai to try things in, its own install dirs and git repo
command: argc.sh
tools: [git]
requires: [core]
files: []
config: {}
---

# sandbox

a skogai that sees nothing from outside: `<dir>/global` is its global
install dir, `<dir>/repo` a git repo whose `.skogai` is its local one. the
`test` module gives every test an empty one; by hand or for an agent it is a
place to try the built skogai without touching the real install.

| command | |
|---|---|
| `new [dir] [--empty] [--shell]` | make it, every module installed and skogai built unless `--empty`; prints the env lines that switch a shell into it |

`<dir>/run <cmd>...` runs one command inside it, for callers whose env does
not persist between commands. a dir made by an earlier sandbox is replaced;
any other existing one is refused.
