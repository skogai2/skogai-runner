# Module install by copy

`skogai module install|uninstall|ls` (script: `src/core/module/usage.sh`) puts a module's toml ([module format](module.md)) into the mise `conf.d` of a level, after its rules and tests pass. mise then loads the module's `[env]`, `[tasks]` and relationships for every project at that level. Decided with skogix 2026-11-07 (see `.harness/context_summary.md`, "mise conf.d").

Status words: **implemented** means the code does it; **verified** means a test in `tests/install.bats` covers it; **planned** is not built. Everything described here is implemented and verified unless marked otherwise.

## Levels and directories

| level | install and uninstall write | ls, rules, duplicate scan and required-by read |
| --- | --- | --- |
| `system` | `${MISE_SYSTEM_DIR:-/etc/mise}/conf.d` | the same |
| `global` (default) | `${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}/conf.d` | the same |
| `local` | `<git root>/.mise/conf.d` | that, then `<git root>/.config/mise/conf.d` (mise loads both) |

The git root is `git rev-parse --show-toplevel` from the current directory. Outside a git work tree the local level is exit 2 for install and uninstall, and is left out of everything that reads. Paths in the output are built literally from these variables and the git root, never through realpath. Precedence, broadest first: system, global, local.

## What counts as a module file

A `*.toml` in one of those directories that yq parses and whose `_.skogai` is a table with exactly one key whose value is a table; the key is the name. Every other file (the host's own conf.d files, several `_.skogai` keys, unparseable files) is ignored by all three commands and never touched. Dot files are not looked at.

## install

`skogai module install [--level system|global|local] <path>`. `<path>` is a module toml file, or a directory `<d>` holding `<basename d>.toml`. Anything else is exit 2 and nothing is written. Steps, all before any effect:

1. Rules. The module files installed at the target level and every broader level are copied flat into a fresh temporary directory under their own file names (broadest first, a later file of the same name replaces an earlier one), except `<conf.d>/<name>.toml` at the target level, which this install would replace. The source goes in under its own file name. `contract/usage.sh check` runs on every `*.toml` there in one call. The source's verdict must be `valid`. So: an invalid module is rejected with its contract reasons, a `depends_on` that names a module not installed at the target or a broader level is `missing-dependency`, and two modules owning the same path are `ownership-conflict` (paths compare relative to the conf.d, since all files sit in one directory). If the checker exits non-zero or does not print one verdict per file, install exits 2 with its stderr passed through.
2. Duplicate name. If the source is valid and a module file of the same name is installed anywhere (narrower levels too) other than `<conf.d>/<name>.toml` itself, the install is rejected with `duplicate-name`. This scan is separate from the checker so narrower levels do not satisfy `missing-dependency`.
3. Tests. If `<path>` is a directory with a `tests/` subdirectory holding a `*.bats` file, `bats <d>/tests` runs with `<d>` as working directory and must exit 0, else `tests-failed`. Its output goes to stderr. A toml file path has no tests.
4. Target `<conf.d>/<name>.toml`. If it exists and is not a module file declaring that name, exit 2, nothing written.

Effect: identical bytes at the target means nothing is written (`unchanged`, mtime kept). Otherwise the conf.d directory is created if needed, the source is copied to a temporary file in it named `.install-XXXXXX` (not `.toml`, so mise never loads a half-written file; mode 0644) and renamed over the target in one step (`installed`, or `updated` when a target existed).

Only the toml is copied. README.md, SKOGAI.md and tests/ stay in the source, so a module's task must not depend on files beside its toml.

Output, one JSON line:

```json
{"module":"alpha","level":"global","path":"/home/u/.config/mise/conf.d/alpha.toml","action":"installed"}
{"module":"bad","level":"global","path":null,"action":"rejected","reasons":["unknown-section"]}
```

`module` is null when the source declares no usable name. Reasons are the contract reasons (sorted, unique), `["duplicate-name"]` or `["tests-failed"]`.

## uninstall

`skogai module uninstall [--level ...] <name>`. The name must match `^[a-z][a-z0-9-]*$` (else exit 2). The target is `<conf.d>/<name>.toml` (local: `<git root>/.mise/conf.d` only).

- absent: `{"module","level","path":null,"action":"absent"}`, exit 0.
- present but not a module file declaring that name: exit 2, untouched.
- another installed module, at any level, lists the name in `depends_on`: `{"module","level","path":null,"action":"rejected","reasons":["required-by"],"required_by":[...sorted]}`, exit 3, untouched.
- otherwise the file is removed: `{"module","level","path","action":"removed"}`. A failing removal is exit 4.

## ls

One line `{"module","level","path"}` per module file: levels in the order system, global, local; within a level directory by directory in the table's order, files C-locale sorted by file name. The same order is used for the rules copy, the duplicate scan and required-by. No modules, no output, exit 0.

## Exit codes

0 done (including unchanged and absent). 1 only from usage's own parser (a command line that does not fit the `#USAGE` spec, such as `--level bogus` or a missing argument). 2 bad arguments, path or name, target conflict, local level outside git, checker failure, a missing tool (git, yq, jq, mikefarah's yq, and bats when the module has tests). 3 rejected. 4 the effect failed (cannot create, copy, rename or remove; no stdout, the temporary file is removed). Diagnostics are on stderr, JSON on stdout.

The script also works through a registry symlink: `skogai register src/core/module/usage.sh module`, then `skogai module install <dir>`.

## Known limits

- The same name at two levels is refused, not shadowed.
- `owns` paths of installed modules are compared relative to their conf.d, as all files sit in one directory in the rules step.
- Module tests run unisolated, in the module's directory, with the caller's environment.
- The duplicate rule and the checker both look at the file name stem: an installed module under another file name than its name still counts for duplicates and conflicts, but is only replaced by an install under `<name>.toml`.
- Not built: install from a URL or git, scaffolding, `module diff`, copying files beside the toml, `run` with the module's env, `depends_on` at run time.
