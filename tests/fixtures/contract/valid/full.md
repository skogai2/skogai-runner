---
name: full
description: every key
depends_on: [full]
reads: [input.txt, .]
writes: [out/, ./log//]
owns: [./out, log]
watches: [conf/a.toml]
defaults:
  level: 1
---
# full

body text
