---
type: module
name: core
description: finding, installing, scaffolding and running modules, and their config defaults
command: argc.sh
tools: [git, yq, argc]
requires: []
files:
  - templates/
  - tests/contract.bats
config:
  module:
    install: local
---

# core

the module every other one stands on. `skogai system` is its command;
`skogai core ...` is the same thing spelled out. what a module
is, how it is found, installed, configured and run: `docs/module.md` in
skogai-runner.

| command | |
|---|---|
| `system ls` | every module found, its layer and description |
| `system show <name>` | its manifest, where it is, what it is missing |
| `system check [name\|path]...` | check modules against the spec |
| `system add <name\|path> [--to] [--apply]` | copy a module into `.skogai/modules` or the global dir |
| `system diff <name>` | an installed copy against its source |
| `system new <name> <description> [--to]` | scaffold from `templates/module/` |
| `system build [--to] [--shell]` | generate `skogai` for a shell: one argc file over every module, man pages, completions |
| `system env <name>` | the env a module's command runs with |
| `system defaults [name]...` | every `config:` default, mounted under its module's name |
| `system command <name>` | the path of a module's argc script |
| `system source <name>` | the path of a module's source, what it is installed from |

## config

a module's `config:` is the default of each of its keys: `runner.model` is
`SKOGAI_RUNNER_MODEL`, and the env always wins. anything between the default
and the env comes from installed modules that offer an `env:` script, which
every skogai command runs with; the `config` module is that, through mise.
without one installed, a key is its default or the env.

| key | default | |
|---|---|---|
| `core.module.install` | `local` | where `system add` and `system new` put a module without `--to`: `local` or `global` |

`templates/main.sh` is what `system build` fills in. `docs/argc/` is the argc
reference every module's command is written against.

`templates/module/` is what `system new` scaffolds (`_name_` in a path becomes
the module's name); edit an installed copy to change it for one repo.

## tests

`tests/contract.bats` is what every module is held to, offered so an
installed core keeps it; the `test` module runs it against each module.
`tests/core.bats` is core's own.
