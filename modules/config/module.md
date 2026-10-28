---
type: module
name: config
description: config layers through mise, skogai.toml and skogai.<module>.toml beside mise.toml
command: argc.sh
env: env.sh
tools: [mise, jq]
requires: [core]
files: []
config: {}
---

# config

opt-in config layers for skogai, kept by mise. found only, `skogai config`
reads and writes them; installed (`skogai system add config --apply`), every
skogai command runs with them, through `env.sh`.

a key is a module's name and its own: `runner.model` is
`SKOGAI_RUNNER_MODEL`, an `[env]` entry in a mise file. fold order, later wins:

1. the module's `config:` default (core)
2. `conf.d/skogai.toml` in mise's system dir, then in its global dir
3. in each dir from `/` down to here: `skogai.toml`, `skogai.<module>.toml`,
   then mise's own files (`mise.toml`, `mise.local.toml`, `mise.<env>.toml`, ...)
4. the caller's env

skogai's files sit under the user's, so `mise.toml` is always the user's diff
on top. mise only reads them with `MISE_OVERRIDE_CONFIG_FILENAMES` set; skogai
sets it for its own commands, and `skogai config env` prints it for a shell
that should see the same.

| command | |
|---|---|
| `get <key> [--show-origin]` | the resolved value, and the file or layer it came from |
| `set <key> <value> [--global] [--module]` | write `skogai.toml` at the git root, the global `conf.d/skogai.toml`, or `skogai.<module>.toml` |
| `unset <key> [--global] [--module]` | remove it from that file |
| `list [--show-origin]` | every resolved key |
| `env` | the mise layers as export lines, `MISE_OVERRIDE_CONFIG_FILENAMES` first |
| `files` | every skogai layer file, and whether it is there |
