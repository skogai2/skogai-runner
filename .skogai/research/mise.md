# mise as a config substrate: research notes

Tested: mise 2026.10.17 linux-x64 (2026-10-21), on 2026-11-07. mise 2026.11.3 exists and the docs on GitHub `main`
describe it, so some documented features are newer than the installed binary (marked below).

Every probe ran in an isolated env:
`env -i HOME=$S/home PATH=$PATH MISE_CONFIG_DIR=$S/cfg MISE_DATA_DIR=$S/data MISE_CACHE_DIR=$S/cache MISE_STATE_DIR=$S/state MISE_SYSTEM_DIR=$S/sys MISE_TRUSTED_CONFIG_PATHS=$S MISE_YES=1`.
The wrapper (`m.sh`) and the probe scripts (`p1.sh` … `p14.sh`) are in
`/tmp/claude-1000/-home-skogix-skogai-runner/85a17bf4-0c99-4408-b9b0-df173714ecb6/scratchpad/mise-research/`. Re-run any of them with `bash pN.sh`.

Labels: **VERIFIED** means I ran it (probe named). **DOCUMENTED** means the `--help` of this binary or a cited URL says so. **UNKNOWN** means neither.

## Summary: how mise can store and resolve user key/value config

1. **`[env]` plain value**: merges per key and the later layer wins. It **beats the caller's env** and is exported to tasks. Source attribution is correct.
2. **`[env]`/`[vars]` directive `{ default = "d" }`**: fills only when no earlier layer gave a value and the caller env lacks that exact name. A later-layer `default` never replaces an earlier value. `mise env --json-extended` / `mise set` report the true source. This gives module defaults with no template tricks.
3. **`[env]` template `{{ get_env(name='K', default='v') }}`**: layered, and the caller env wins. It is opaque to mise: the stored value is a template, not a value.
4. **`[vars]`**: values used only inside templates and never exported. They merge per key. `mise vars ls` lists value + source and `mise vars NAME` prints the resolved value. The directives `default`/`required`/`prompt`/`redact` apply. **Saved answers** go to `$MISE_STATE_DIR/vars.toml` (per machine, outside every config file). They rank above `default` and below any config-file value.
5. **`[_]`**: free-form typed TOML (string/int/float/bool/list/table). mise never merges or reads it. `mise config get/set` reads and writes it one file at a time, with types. Templates can reach it only through `read_toml(path=...)`.
6. **`[settings]`**: a closed schema. Unknown keys are ignored and `mise settings set` refuses them, so it cannot hold user keys.
7. **Task `usage` flags with `env="K" default="d"`**: CLI flag > env (caller env or mise `[env]`) > usage default. `choices` and required args are validated, and help comes for free. This is a native "command parameter" top layer.
8. **Layer selectors**: system/global/conf.d/project/parent dirs, `MISE_ENV` profiles (`mise.<env>.toml`, `config.<env>.toml`), and the global `config.override.toml` above all project files.
9. **Write CLIs**:
   - `mise set/unset` writes `[env]`. Target the file with `--file`, `-g`, `--override` or `-E`.
   - `mise config set` writes any key, typed, to one file (`--file`, `-g`, `--system`, `--override`).
   - `mise vars NAME=V` writes the state file.
   - `mise settings set` writes settings.
10. **Read CLIs**:
    - with sources: `mise env --json-extended`, `mise set`, `mise vars ls`, `mise settings ls --json-extended`
    - `mise config ls --json` lists the files
    - `mise config get` reads one file, with no merge
    - `mise tasks ls --json` / `mise tasks info --json` show tasks

## Q1. Every place mise holds user data

| place | meant for | layer merge | who reads it | CLI |
| --- | --- | --- | --- | --- |
| `[env]` | env vars exported to tools/tasks/`exec`/shell | per key, later wins (VERIFIED p2) | tasks (exported), templates via `env.K`, `mise env` | `mise set/unset`, `mise config set env.K`, `mise env --json[-extended]`, `mise set` (list with source) |
| `[env]` directives | `_.file` (dotenv/json/yaml), `_.source` (bash script), `_.path` (PATH prepend), `{value, default, required, redact, age}` per key | per key | same as `[env]` | same |
| `[vars]` | template-only values | per key, later wins (VERIFIED p2) | templates `{{ vars.x }}` in config, tasks, hooks; **not exported** (DOCUMENTED vars.md) | `mise vars`, `mise vars ls`, `mise vars NAME[=V]`, `mise vars prompt`, `mise vars unset`, `mise config set vars.x` |
| `$MISE_STATE_DIR/vars.toml` | per-machine saved answers for vars | single file, ranks above `default`, below any config value (VERIFIED p3) | as `[vars]` | `mise vars NAME=V`, `mise vars prompt`, `mise vars unset` |
| `[settings]` | mise's own behaviour, closed schema | per setting (DOCUMENTED configuration.md; source shown VERIFIED p2) | mise | `mise settings get/set/add/unset/ls [--json-extended]` |
| `[tools]` | tool versions | per tool, nearest entry replaces that tool's whole entry (DOCUMENTED) | mise | `mise use/unuse`, `mise config set tools.x` |
| `[tasks]` | runnable tasks | per task name: a nearer **directory** replaces the whole task; inside one directory a block without `run` adds metadata (VERIFIED p12) | `mise run`, `mise tasks` | `mise tasks add/edit/ls/info --json` |
| `[task_config]` | `includes` (task dirs/files, git::, oci::), `dir` | not covered by the docs' merge table (UNKNOWN) | mise | `mise config set` |
| `redactions` | list of env/var name globs to mask in output | UNKNOWN merge | mise | `mise config set` |
| `[hooks]` | `enter`, `leave`, `cd`, `preinstall`, `postinstall` scripts | no per-section rule documented; included-file hooks run before the includer's (DOCUMENTED) | mise (activate) | none dedicated |
| `[_]` | "free-form data for your own use; mise never reads it" (`mise config explain`, VERIFIED p8) | **no merge**; each file separate | only `mise config get/set` (per file) and `read_toml()` in templates | `mise config get/set` |
| other top-level tables (`[skogai]`) | none | n/a | mise prints `WARN unknown field` (VERIFIED p8) | `mise config explain` flags it "not a key mise reads" |
| `mise.<env>.toml` | profile files selected by `MISE_ENV`/`-E` | ordinary layers; with `MISE_ENV=a,b`, `b` beats `a` (VERIFIED p11) | everything | `mise set -E env`, `-E` on any command |

Details, VERIFIED:
- **`mise env --json` omits variables equal to the caller's env** (p4: `D1=caller` gave `null`). Use `mise exec -- printenv` or `--json-extended` to see the effective value.
- **`mise env --json-extended`** gives `{K: {value, source}}`. For the plain and directive forms the source is the file that supplied the value. For the template form `{{ env.K | default(...) }}` the source is the file holding the template, even when the value came from an earlier layer (p5, p11: `T  global  .../mod.toml`). `mise set` (list) has the same attribution.
- **`_.file` with `redact = true`** marks every loaded key as redacted. `mise set` shows `[redacted]`, and `mise env --redacted --json` lists them unmasked. Task output redaction is a **substring replace**: `TOKEN=tok` turned the word `token=` into `[redacted]en=` (p11).
- `_.source` and `_.file` values carry their file as the source (p11). `_.path = ["{{ config_root }}/bin"]` is prepended to PATH (p11).
- A wrong type for a known key (`[redactions]` as a table) is a hard parse error with line/column for **every** command (p11).

## Q2. Config file discovery and precedence

VERIFIED (p1, p1b). I put one file at every candidate path, each setting `[env] WHO`. Running `mise config ls` from `proj/sub` in a git repo lists the files lowest to highest:

```
$SYS/conf.d/*.toml                (MISE_SYSTEM_DIR; default /etc/mise)
$SYS/config.toml
$CFG/conf.d/*.toml                (MISE_CONFIG_DIR; default ~/.config/mise)
$CFG/config.toml
$CFG/config.<env>.toml            (MISE_ENV=<env>)
$CFG/config.local.toml
<each parent dir, outermost first>/mise.toml ...
proj/.tool-versions
proj/.config/mise/conf.d/*.toml
proj/.config/mise/config.toml
proj/.config/mise.toml
proj/.mise/conf.d/*.toml
proj/.mise/config.toml
proj/mise/config.toml
proj/mise.toml
proj/.mise.toml
proj/mise.<env>.toml              (MISE_ENV=<env>)
proj/.config/mise/config.local.toml
proj/.config/mise.local.toml
proj/mise.local.toml
proj/.mise.local.toml
proj/mise.<env>.local.toml        (MISE_ENV=<env>)
proj/sub/mise.toml                (nearer directory beats its parents, as a whole group)
$CFG/config.override.toml         (labelled "override": beats every project file, mise.local.toml included)
$CFG/config.<env>.override.toml   (above config.override.toml)
```

`mise config ls --json` gives the same list in the **opposite** order (highest first) as `{path, tools, override?}`. Resolved `WHO`:
- from `proj/sub`: `override`
- without the override file: `sub`
- from `proj`: `p_dotmise_local`
- with `MISE_ENV=dev`: `p_mise_dev_local`

The exact slot of `$CFG/config.<env>.toml` relative to `config.local.toml` comes from one JSON listing. Treat it as approximate.

Other rules:
- conf.d fragments load in name order, before their directory's `config.toml`. VERIFIED.
- **No git requirement**: project files load with `.git` removed, and the walk goes up past the git root (the parent `w/mise.toml` loaded). VERIFIED p1b.
- Path-control env vars (p10, p12):

| variable | effect | label |
| --- | --- | --- |
| `MISE_GLOBAL_CONFIG_FILE=f` | replaces the global config files with `f` and **turns off `config.override.toml`** | VERIFIED |
| `MISE_CONFIG_FILE=f` | behaves the same here | VERIFIED; not in the docs |
| `MISE_SYSTEM_CONFIG_FILE=f` | replaces the system config | VERIFIED |
| `MISE_OVERRIDE_CONFIG_FILENAMES=skogai.toml` | the project filename set becomes exactly `skogai.toml` (mise.toml no longer loads) | VERIFIED |
| `MISE_DEFAULT_CONFIG_FILENAME=skogai.toml` | adds `skogai.toml` as a project file above `mise.toml`; it is also the file `mise set`/`--file <dir>` creates | VERIFIED |
| `MISE_IGNORED_CONFIG_PATHS=dir` | drops that dir's files | VERIFIED |
| `MISE_CEILING_PATHS=dir` | the search does not go above `dir` | VERIFIED that the project still loads |
| `--no-config` / `MISE_NO_CONFIG=1` | loads nothing | VERIFIED |
| `MISE_SYSTEM_DIR` | moves the system dir | VERIFIED. The docs name `MISE_SYSTEM_CONFIG_DIR` instead (UNKNOWN in this version) |
| `.miserc.toml` | read before any `mise.toml`; sets environments and discovery options | DOCUMENTED (configuration.md), not probed |

- **Trust** (p10): an untrusted project file holding any `[env]`, even a plain value, is a hard error ("not trusted") for `mise env`. A file holding only `[_]` reads fine with `mise config get`. `mise run`/`exec`/`install` auto-trust their active config (DOCUMENTED `mise trust --help`). Global and system config need no trust. Paranoid mode ties trust to file contents (DOCUMENTED).
- **Write targets** (DOCUMENTED `--help`):
  - `mise set`/`unset` write "the lowest-precedence TOML file in the nearest config directory" (`mise.toml` rather than `mise.local.toml`), creating `./mise.toml` if none exists. In `$HOME` they write the global config.
  - `mise config get/set` default to the highest-precedence loaded TOML file, excluding override files.
  - `mise settings set` defaults to global (`--local` writes the nearest project file).
  - `mise set --override` writes `$CFG/config.override.toml`.

## Q3. Tera templates

Context, VERIFIED (p6), unless marked otherwise:

| item | result in 2026.10.17 |
| --- | --- |
| `cwd`, `config_root`, `config_source` | work (`config_root` is the project dir for `.config/mise.toml` too, DOCUMENTED) |
| `env.K` | the process env plus `[env]` resolved so far |
| `vars.x` | works |
| `mise_env` | a JSON list such as `["dev"]` |
| `xdg_state_home` and friends | work |
| `exec(command=...)` | works |
| `read_toml(path=config_source)` | works: a template can read its own file's `_` table, e.g. `{% set f = read_toml(path=config_source) %}{{ f._.skogai.hello.owns \| join(sep=',') }}` gives `greeting.txt` |
| `os()`, `arch()` | work |
| `get_env(name=...)` | sees only the env mise started with, not `[env]` (`T_GET_ENV_SEES_ENV` gave `no`) |
| `mise_config_dir` | **undefined** here (DOCUMENTED on main, so newer than 2026.10.17) |
| a `config` variable | does not exist; there is no template access to arbitrary merged tables |

Full function/filter list: DOCUMENTED at https://github.com/jdx/mise/blob/main/docs/templates.md. Notable entries: `read_json`, `read_yaml`, `read_file`, `throw`, `quote`, `hash`, and the tests `defined`/`exists`. `exec`/`read_*` are disabled with `MISE_SAFE=1`.

Evaluation order:
- **Top-level `[vars]` render at config load**, each entry may reference earlier ones, and the result is stored as a string. A var built from another var keeps the value it had when built: a global `dep = "dep-from-{{ vars.g }}"` stayed `dep-from-global` (VERIFIED p4). DOCUMENTED in vars.md: overriding the base var later does not re-render `dep`.
- **`[env]` renders after all `[vars]` are merged.** A global `[env] G = "{{ vars.late }}"` gave the project's `late` (VERIFIED p4).
- `[env]` entries see earlier `[env]` entries, including `_.file`/`_.source` output (VERIFIED p6 `T_EARLIER`, p11 `AFTER`).
- Task fields (`run`, …) render at run time and can use the task's `vars`, `usage.<arg>` and `env` (VERIFIED p9).
- Keys are never rendered (DOCUMENTED).

Can arbitrary TOML tables be read? Not from templates, except with `read_toml(path=<file>)` on a known file, which reads that one file with no merge. Not from the CLI except per file with `mise config get` (Q4).

## Q4. Arbitrary user keys through mise's own CLI

VERIFIED (p7, p14):
- `mise config set KEY VALUE` writes any dotted path, e.g. `_.skogai.hello.count 3` gives `count = 3` under `[_.skogai.hello]`.
- Types: by default `true`/`false` become bools and anything else a string. `-t integer|float|bool|string|list|set` forces a type, and `-t list a,b` gives `["a","b"]`. `--append` appends without duplicating, and `--remove` removes.
- Known settings get their declared type.
- Directive forms can be written too: `mise config set env.K.default hi` gives `[env.K] default = "hi"`, and `vars.x.required "msg"` works.
- Target: the highest-precedence loaded TOML file, or `--file f|dir`, `-g`, `--system`, `--override`.
- **A project target must already exist.** `config set` with no project file fails ("No mise.toml file found"), and `--file mise.toml` on a missing file fails ("config file not found"). `-g` and `--system` create their files.
- An existing comment survived edits.
- `mise config get KEY` prints a scalar raw, a list as `["a", "b", "c"]`, and a table as TOML. There is **no `--json`**. A missing key exits 1 with `Key not found: … in <file>`.
- It reads one file: by default the highest-precedence loaded TOML (`-g`, `--system`, `--override`, `--file` select another). **No merge across layers**: `config get _.skogai` from the project returned only the project's `x`, not the global `y` (p2).
- `mise config explain [--json] [KEY]` lists keys with line numbers and schema descriptions. `[_]` shows as free-form, and unknown keys show as "not a key mise reads".
- `mise settings set skogai.x 1` gives `Unknown setting` (p8).
- `mise vars NAME=VALUE` stores any name (declared or not) in `$MISE_STATE_DIR/vars.toml`. **It is keyed by name alone, per machine, shared by all projects** (DOCUMENTED vars.md; file content VERIFIED p3).

## Q5. Tasks as the module surface

VERIFIED (p9, p12, p13) unless marked:

**Arguments**
- `usage = '''arg "<who>" … flag "-l --loud" … flag "--times <n>" default="1"'''`. The values arrive as env `usage_who`, `usage_loud=true` and `usage_times`, and in templates as `{{ usage.who }}`.
- `option` is **not** a valid usage key ("unsupported spec key option"); use `flag "--x <v>"`.
- A missing required arg gives `Missing required arg: <who>`, exit 1.
- `flag "--mode <m>" { choices "a" "b" }` rejects a wrong value: `Invalid choice for option mode: c, expected one of a, b`.
- **`flag "--greeting <g>" env="SKOGAI_HELLO_GREETING" default="fallback"`** resolves CLI > env > usage default. The env here is the caller env or a mise `[env]` value, including `{default=…}` directives.
- `mise run hello --help` prints generated help that shows `[env: …]`, `(default: …)` and the possible values.
- A broken usage spec in one task makes any run that touches that task fail at validation.

**Composition**
- `depends = ["pre", "greet bob"]` (with args), `depends_post = ["post"]`. The order ran pre, greet, main, post.
- `run = [{ task = "greet carol --loud" }, "echo after", "mise run -q greet dave"]`: both the `{task=…}` step and a nested `mise run` work.
- A failing step stops the list and the exit code propagates: `exit 7` came back as mise exit 7.
- `wait_for`: DOCUMENTED, not probed.
- `mise run a ::: b` runs tasks in parallel (DOCUMENTED).

**Output**
- The task's stdout goes to mise stdout and its stderr to mise stderr, and mise's own errors (`[fail] ERROR task failed`) go to stderr.
- A **single** task's stdout is byte-clean (`{"ok":true}\n`).
- **When several tasks run (depends), lines get a `[task]` prefix**: `[pre] pre`, `[greet] …`. Use `--output interleave` (or `-r/--raw`) to keep machine output clean.

**Task-level `env` and `vars`**
- Task `env = {…}` is exported to that task only.
- Task `vars = {…}` overrides `[vars]` only while that task renders.
- Project `[env]` is visible inside tasks.

**File tasks**
- `.mise/tasks/hello/world` becomes the task `hello:world`.
- `#MISE description=…`, `#MISE env={…}` and `#USAGE arg/flag` lines work, and positional args also arrive as `$*`.
- Global file tasks live in `$CFG/tasks/`.
- Other default directories: `mise-tasks/`, `.mise-tasks/`, `.mise/tasks/` (DOCUMENTED `mise tasks ls --help`).

**`task_config.includes`**
- It **replaces** the default task dirs. With `includes = ["../lib/tasks"]` the project's `.mise/tasks/` tasks disappeared, so add `".mise/tasks"` back explicitly.
- An included task runs with cwd and `MISE_CONFIG_ROOT`/`MISE_PROJECT_ROOT` set to the including project, not the library dir.
- git:: and oci:: sources: DOCUMENTED.

**JSON output**
- `mise tasks ls --json` gives an array of `{name, aliases, description, source, config_sources, depends, depends_post, wait_for, env:["K=V"], dir, hide, global, usage (raw string, **empty for file tasks**), run, file, …}`.
- `mise tasks info T --json` returns the same fields minus `usage`/`global`, plus `usage_spec` (parsed, works for file tasks too), `cache` and `skip_if`.
- Task `vars` do not appear in either.

**Merge across layers**
- A later **directory's** `[tasks.x]` replaces the whole task.
- A metadata-only block there (`description` or `env`, no `run`) **silently empties `run`**: `mise run hello` then does nothing and exits 0.
- Inside one directory (two conf.d fragments) a run-less block merges metadata into the existing task. The fragment `zz.toml`'s description was added and the `run` from `hello.toml` was kept.

## Q6. Typed or declared settings and free validation

- **mise's own settings** have a schema with types and descriptions (`mise settings ls --json-extended` gives `{value, type, description, source}`). `config set` coerces known settings to their declared type. VERIFIED p2, p7.
- **Schema check on load**: a known key with the wrong type is a hard parse error with location (p11). An unknown top-level key gives a warning (p8). `mise config explain` shows schema descriptions per key and suggests corrections for typos (DOCUMENTED help example `experimantal`). `mise fmt --check` exits 1 on unformatted files (DOCUMENTED).
- **`required = "help text"`** on `[env]` or `[vars]`: if unset, `mise env`/`mise run` fail with the help text; the caller's env satisfies it (p4, p14). `mise vars ls` only warns.
- **`default = "d"`**: a fill-only default (Q1, p5).
- **`redact = true` / `redactions = ["GLOB"]`**: masks values in output (p11).
- **`prompt = "…"`** (vars only): interactive per-machine answers (DOCUMENTED, CLI VERIFIED p3).
- **`age`**: encrypted values (experimental, DOCUMENTED).
- **usage specs** add typed args/flags, `choices`, `default`, `env=` binding, required args, generated help and completion, plus `mise tasks validate` (p13).
- **None of this types user values in `[env]`/`[vars]`.** They are all strings. `[_]` keeps TOML types but has no validation.

## Corrections to repo notes

Checked against `.harness/context_summary.md` ("Config layering on mise"), `docs/config.md` and `docs/module.md`.

1. **The "module default" form is not the only way, and it misattributes the source.**
   - `K = "{{ env.K | default(value='d') }}"` does behave as described (VERIFIED p5).
   - But mise has a native directive, `K = { default = "d" }`, with the same semantics: a later layer's default never replaces an earlier value, and the caller env wins.
   - With the directive, `mise env --json-extended` and `mise set` report the real source file. With the template form they name the module file even when global supplied the value.
   - So "origin must be computed by skogai" holds only because of the template form.
2. **"Command parameters are a layer in the model but not handled"**: mise/usage already handle it. A task flag with `env="SKOGAI_X" default="d"` resolves CLI > env (caller env or mise `[env]`) > default (VERIFIED p13).
3. **The layer list in `docs/config.md` leaves out files mise loads**:
   - `$CFG/config.local.toml`
   - parent-directory `mise.toml` files and nearer subdirectory files
   - `.config/mise.toml`, `.config/mise/config.toml`, `mise/config.toml`, `.mise/config.toml`, `.mise.toml`, `.mise.local.toml`, `.config/mise.local.toml`
   - `mise.<env>.toml` and `config.<env>.toml`
   - `$CFG/config.override.toml`, which ranks **above** `mise.local.toml`

   docs/config.md admits this under "Known limits", but the table reads as complete.
4. **Naming clash on "override"**: skogai's `set --override` writes `mise.local.toml`, while mise's `mise set --override` writes `$CFG/config.override.toml` (global, above all project config). Same word, different file and scope.
5. **"local = `<git root>/mise.toml`"** is a skogai rule. mise itself ignores git:
   - it loads project files in any directory from `/` down to cwd, with or without `.git`;
   - `mise set` writes the nearest config directory's lowest file, not the git root's.

   docs/config.md's "Outside a git work tree the two project directories are not read" describes skogai's `files` listing, not mise's loading. mise **does** read them, so a module in a non-git dir's `.mise/conf.d` is active in mise while skogai lists it as absent.
6. **"A later layer's `[tasks.x]` replaces the whole task"** (docs/module.md) is true across **directories**. Inside one directory (conf.d fragments) a block without `run` merges metadata. A metadata-only override in a later directory silently leaves the task with an empty `run` (VERIFIED p12).
7. **"`mise config get _.x` reads only the nearest file"**: more precisely, it reads the highest-precedence loaded TOML file, excluding `config.override.toml` (`--file`/`-g`/`--system`/`--override` select another). Confirmed: there is no merge.
8. **"`mise set` (list) names the module file as source even when another layer supplied the value"**: true only for template-form values. Plain and `{default=}` values are attributed correctly (VERIFIED p11: `M global .../cfg/config.toml`).
9. **"A plain `[env]` value beats the caller's env; a `get_env` default does not"**: confirmed (p5). Also add that `{ default = … }` and `required` defer to the caller env.
10. **The doc claim in vars.md that the process env ranks highest** holds only when the winning definition is a `default`/`required` directive. A plain `[vars]` value in a later file beat a caller env var of the same name (VERIFIED p3: `gday` with `hello_greeting=yo` in the env).
11. **mise.toml writes need trust, `_` does not**: a project file with any `[env]` errors as untrusted under `mise env` unless it is trusted. The tests' `MISE_TRUSTED_CONFIG_PATHS` hides this.

## Open questions

- **Which storage model does skogix want for user values?** The candidates below are all native and visible to `mise vars ls`/`mise env --json-extended` with sources:
  - (a) `[vars]` with `{default}` in modules plus plain values in user layers, bridged to env by the module (`[env] SKOGAI_X = "{{ vars.x }}"`) or to task flags. Note that a plain user value then beats the caller env.
  - (b) `[env]` `{default}` in modules plus plain `[env]` in user layers.
  - (c) per-machine `mise vars NAME=V` answers. These are not layered and are shared by all projects with that name.
  - (d) typed data in `[_.skogai]`, with skogai doing the merge itself.
- `[vars]` names double as the caller-env names for `default`/`required`, case-sensitively. A lowercase var `hello_greeting` reads the env var `hello_greeting`, not `HELLO_GREETING` (VERIFIED p3). Is that acceptable, or should var names be the `SKOGAI_*` env names?
- I don't know a mise-native way to make a user-layer value lose to the caller env other than the `get_env` template. `{default}` in a user layer loses to every earlier plain value, so it doesn't layer.
- These features were not checked against 2026.11.3: `mise vars --json`/`--json-extended` (documented on main, absent in 2026.10.17), `mise_config_dir`, and `MISE_SYSTEM_CONFIG_DIR` vs `MISE_SYSTEM_DIR`. Pinning a mise version in `mise.toml` (`min_version`) may matter.
- Merge rules for `[hooks]`, `redactions`, `[task_config]` and `wait_for` behaviour were not probed.
- The task output redaction substring bug (`token` → `[redacted]en`) is version-sensitive. It is worth noting if skogai relies on `redact`.
