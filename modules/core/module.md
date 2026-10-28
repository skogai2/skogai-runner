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
`skogai core ...` is the same thing spelled out.

## running

`bin/skogai` is the binary, `/usr/bin/skogai` once installed. it reads one
thing from here: `command:`, core's argc script, from the
`share/skogai/modules/core` of its own prefix. from a checkout that is
`share/skogai/modules`, a link to `modules/`.

1. the nearest `.skogai/bin/skogai` up from here is handed off to (argc's
   `ARGC_SCRIPT_NAME`), and its `.skogai` is the local dir. with
   `SKOGAI_LOCAL_DIR` set, it is that dir's `bin/skogai` or none.
2. `skogai <name> ...` is `skogai-<name>` on PATH, the local and global
   `bin/` first, like git: any executable. `system add` writes one for every
   module with a command.
3. else a module found by that name runs its `command:` with
   `system env <name>`; anything else is core's.

## a module

a directory with a `module.md`; `system check` is the spec, and
`tests/contract.bats` what every module is held to.

| field | read by |
|---|---|
| `type`, `name` | `check` only; the name is the directory's |
| `description` | `ls`, and the help `build` makes |
| `command` | dispatch, `command`, `build`, `add`; checked to parse with argc |
| `env` | run before every command once the module is installed |
| `tools` | `show` and `add` say what is missing, `check` warns |
| `requires` | `check` (everything but core requires core), `test`'s order |
| `files` | what `add` copies beside `module.md`, the command and `env` |
| `config` | the defaults of its keys, below |

the markdown under the frontmatter is for people: nothing reads it.

| command | |
|---|---|
| `system ls` | every module found, its layer and description |
| `system show <name>` | its manifest, where it is, what it is missing |
| `system check [name\|path]...` | check modules against the spec |
| `system add <name\|path> [--to] [--apply]` | copy a module into `.skogai/modules` or the global dir, and its `bin/skogai-<name>` |
| `system diff <name>` | an installed copy against its source |
| `system new <name> <description> [--to]` | scaffold from `templates/module/` |
| `system build [--to] [--shell]` | write `bin/skogai`, the runner handed off to (one argc file over every module), and man pages and completions in `tmp/skogai` |
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
