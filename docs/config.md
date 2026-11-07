# Config over mise layers

`skogai config get|set|unset|list|files` (`src/core/config/usage.sh`, a `usage bash` script; register it with `skogai register src/core/config/usage.sh config`) reads and writes `SKOGAI_*` settings that live in mise's own `[env]` tables, so the value a user sets is the value a module's mise task sees. Settled with skogix 2026-11-07 (`.harness/context_summary.md`, "Module model and config answers").

Status words: **implemented** means the code does it; **verified** means a test in `tests/config.bats` covers it (isolated mise, `env -i`, every `MISE_*` dir under the test's tmp dir, a `git init` project); **planned** is not built.

## Layers

Later wins (implemented, verified):

| layer | where | written by |
| --- | --- | --- |
| module default | an `[env]` entry in a module toml in a conf.d, form `K = "{{ env.K \| default(value='d') }}"` | the module author |
| system | `${MISE_SYSTEM_DIR:-/etc/mise}/config.toml` | `set --system` |
| global | `${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}/config.toml` | `set --global` |
| local | `<git root>/mise.toml` | `set` (default) |
| override | `<git root>/mise.local.toml` | `set --override` |
| caller env | the environment of the process that runs mise | the caller |

Command parameters (a task's own usage args) are a layer in the model but not handled here.

Why the caller env wins: `set` stores each value as `K = "{{ get_env(name='K', default='<value>') }}"`. A plain `[env]` value would beat the caller's env; a `get_env` value does not. Why a global setting beats a project-installed module: module defaults use the `env.K | default` form, which sees every earlier layer (see `docs/module.md`).

Module files: a `*.toml` in a conf.d directory that yq parses and whose `_.skogai` is a table with exactly one key whose value is a table; that key is the name. Every other file there is ignored. conf.d directories, in mise's load order: `$SYS/conf.d`, `$CFG/conf.d`, `<git root>/.mise/conf.d`, `<git root>/.config/mise/conf.d`; files in one directory in C-locale order. Outside a git work tree the two project directories are not read.

## Keys

One or more `.`-separated segments, each matching `^[a-z][a-z0-9-]*$`. The env name is `SKOGAI_` plus the key uppercased, `-` removed, `.` replaced by `_`: `hello.greeting` is `SKOGAI_HELLO_GREETING`, `a.b-c.d` is `SKOGAI_A_BC_D`. Any other key is exit 2. The reverse (used by `list`) drops `SKOGAI_`, lowercases and turns `_` into `.`, so dashes do not survive the round trip.

## Commands

All implemented and verified.

- `get [--show-origin] <key>`: prints the resolved value and a newline. Resolved value is the key in `mise env --json` run from the current directory; if mise does not define it but the caller env does, the caller env value; else exit 3 and nothing on stdout. With `--show-origin`: `<origin><TAB><value>`, value escaped. Origin: `env` when the caller env has the variable with the same value; else the highest of `override`, `local`, `global`, `system` whose `[env]` has it; else `module:<name>` of the first module file in load order whose `[env]` has it; else `mise`.
- `list [--show-origin]`: one `key=value` per `SKOGAI_[A-Z0-9_]+` variable in `mise env --json` whose reverse key is valid (others such as `SKOGAI_A__B` are skipped), sorted by key in the C locale; with `--show-origin`, `<origin><TAB>key=value`. Nothing defined: no output, exit 0.
- `set [--system|--global|--override] <key> <value>`: writes the `get_env` form into the chosen file (default local), creating file and directory if missing and replacing an existing entry. At most one level flag. The empty value is allowed; a value starting with `-` needs `--` before the key.
- `unset [--system|--global|--override] <key>`: removes the variable from that file's `[env]`. An absent variable or file is exit 0 with no change.
- `files`: `<layer><TAB><path><TAB><present|missing>` for system, global, local, override, then `module:<name><TAB><path><TAB>present` per module file. Outside a git work tree local and override print `-` and `missing`, and no project module files are listed.

In `list` and `get --show-origin` output a value has `\` as `\\`, newline as `\n` and tab as `\t`; plain `get` prints the raw value.

Writes: the target (or an empty file) is copied to `.skogai-set-XXXXXX.toml` in the same directory (a name mise does not load), edited with `mise set --file` / `mise unset --file`, and renamed over the target. On failure the temporary file is removed and the target is untouched. Comments, other tables and other `[env]` keys are kept in the standard form (`K = "..."` lines under `[env]`); for other forms (inline `env = {...}`, dotted `env.K`, duplicates) the result is whatever the mise edit does. A no-op edit (an `unset` of an absent variable) does not replace the file.

Refused values (exit 2, file untouched): any of `'` `"` `\`, a control character (newline, tab, CR, ...), or `{{ }} {% %} {# #}`.

## Exit codes

0 ok; 1 only from usage's own parser (missing `<key>`, unknown flag); 2 bad args (invalid key, two level flags, local level outside a git work tree), refused value, unparseable target file, missing tool (git, mise, jq, yq) or a failing mise call (its stderr is passed through); 3 `get` of an undefined key. Machine output on stdout, diagnostics on stderr.

## Known limits

- The reverse mapping loses `-`: `a.b-c` is listed as `a.bc`.
- Origin is skogai's ladder, not mise's internal record. A value supplied by a file outside the ladder (a subdirectory `mise.toml`, `.mise.toml`, `.config/mise.toml`, `config.override.toml`, a module default not in the `env.K` form) may be attributed to a ladder file that also defines it, and `mise` is printed when no ladder file defines it.
- A shell with `mise activate` exports the resolved `SKOGAI_*` values, so they show as origin `env`.
- Values with the refused characters cannot be stored (types are deferred).
- `mise unset --file` on a missing file would create it; `unset` therefore returns before calling mise when the file is absent.
- The checker does not enforce the module default form.
- Out of scope: install (F005), run injecting module env into Podman, command parameters as a layer, typed values, `mise.<env>.toml` layers, `config.override.toml`, completion of keys.
