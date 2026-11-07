# Module format v1

A module's declaration is a mise config file, and the contract checker reads it. Decided with skogix 2026-11-07 (see `.harness/context_summary.md`, "Module model and config answers" and "mise conf.d").

Status words: **implemented** means the code does it; **verified** means a test in `tests/module.bats` covers it; **by hand** means someone ran it once and no test covers it; **planned** is not built.

## Layout (convention, not checked)

The checker only receives files, so layout is documentation. In source a module is a directory `<name>/`:

- `<name>.toml`: a mise config file. Later installed as a conf.d drop-in, so the file name is the module name.
- `README.md`: what the module is, every key it sets, what it owns.
- `SKOGAI.md` (optional): agent-facing entry.
- `tests/` (optional).

The example is [examples/modules/hello/](../examples/modules/hello/).

## The declaration

A module is three things in one file: key/value defaults (`[env]`), a usage declaration (the task's `usage`), and relationships (`_.skogai.<name>`).

```toml
[env]
SKOGAI_HELLO_GREETING = "{{ get_env(name='SKOGAI_HELLO_GREETING', default='hi') }}"

[_.skogai.hello]
description = "..."
owns = ["greeting.txt"]
writes = ["greeting.txt"]

[tasks.hello]
usage = 'arg "<who>"'
run = 'echo "$SKOGAI_HELLO_GREETING $usage_who" | tee greeting.txt'
```

- **Name**: the single key under `_.skogai`. It is the name used in the data record, the env prefix, task names and every cross-file rule. The file stem is compared with it only for `name-mismatch`.
- **Which files are modules**: a case-sensitive `.toml` suffix with a non-empty stem. Everything else (`.TOML`, `.toml` alone, `x.toml.md`) is parsed as Markdown, as before.
- **Top-level keys**: `_`, `env`, `tasks`. Under `_` only `skogai`.
- **Relationship keys** in `_.skogai.<name>`: `description`, `depends_on`, `reads`, `writes`, `owns`, `watches`. Type and path rules are the Markdown ones (see `docs/runner.md` and F001). `name` and `defaults` are not allowed (the name is the table key, defaults are `[env]`). `watches` has no behaviour yet (planned).
- **`[env]`** is optional and must be a table. Every key except mise's directive key `_` must start with `SKOGAI_<N>_` and be longer than it, where `<N>` is the name uppercased with `-` removed. Values are not checked (types are deferred).
- **Tasks**: `tasks.<name>` is required, a table with a string `usage` and `run` (string or array of strings). Other tasks must be `<name>:<sub>`, `<sub>` matching `^[a-z][a-z0-9-]*$`. The usage string is not linted.

Implemented and verified: the checker output is the same `{file, verdict, reasons}` per file, reasons sorted and unique, exit codes unchanged. Markdown output is byte-identical to before. Only `src/core/contract/usage.sh` reads modules; the frozen `argc.sh` does not.

## Reasons

Parse stage. Exactly one reason, nothing else is checked, and the file takes no part in cross-file rules:

| reason | when |
| --- | --- |
| `invalid-toml` | `yq -p toml -o json` exits non-zero |
| `no-declaration` | document is empty or not a table, `_` is missing or not a table, or `_.skogai` is missing, not a table, or empty |
| `multiple-declarations` | `_.skogai` has more than one key, even if one equals the stem |
| `not-a-mapping` | the value of the single `_.skogai.<name>` key is not a table (an empty table is valid) |

Collected reasons (any number, with the shared field reasons, then the cross-file ones):

| reason | when |
| --- | --- |
| `invalid-name` | name does not match `^[a-z][a-z0-9-]*$` (shared rule) |
| `name-mismatch` | name differs from the file stem; `hello.toml` with key `Hello` gets both |
| `unknown-key` | key in the relationship table other than the six allowed |
| `env-outside-prefix` | an `[env]` key outside `SKOGAI_<N>_`, or the bare prefix alone |
| `missing-task` | no `tasks.<name>` table with a string `usage` and a `run` |
| `task-outside-prefix` | a task other than `<name>` or `<name>:<sub>` |
| `unknown-section` | a top-level key other than `_ env tasks`, or a key other than `skogai` under `_` |
| `wrong-type` | shared rule; also `env` present but not a table |

The shared cross-file reasons (`missing-dependency`, `duplicate-name`, `ownership-conflict`, `write-not-owned`, `path-outside-scope`) apply to `.md` and `.toml` files together; a workorder and a module that own the same path conflict. An invalid name still takes part in the cross-file rules, as in F001.

Verified by the fixtures in `tests/fixtures/module/` (`valid/`, `invalid/<reason>/`), kept apart from `tests/fixtures/contract/` because `mise run test:argc` runs `contract.bats` against the frozen argc checker.

## Open

- Two modules whose prefixes collide (`a-b` and `ab` both give `SKOGAI_AB_`) are not detected.
- A TOML construct that mise accepts but yq rejects or decodes differently is judged by what yq yields.
- Value types, usage-spec linting, install, config get/set, run executing the task, `depends_on` at run time and `watches` behaviour are planned, not built.

## mise facts (mise 2026.10.17, verified by hand on 2026-11-07, not by a test)

- conf.d is loaded at system (`/etc/mise/conf.d`), global (`~/.config/mise/conf.d`, follows `MISE_CONFIG_DIR`) and project level (`.mise/conf.d`, `.config/mise/conf.d`).
- `[env]` merges key by key across layers, a later layer winning.
- A later layer's `[tasks.x]` replaces the whole task. So only the module's own file defines its tasks and relationships; override files set `[env]` only.
- `mise config get _.x` reads only the nearest file, no merge.
- A plain `[env]` value beats the caller's env; a `get_env` default does not.

The one thing a test does cover (verified, in `tests/module.bats`): copying `hello.toml` into a project's `.mise/conf.d/` and running `mise run -q hello world` under an isolated mise (`env -i`, every `MISE_*` dir under the test's tmp dir, `MISE_TRUSTED_CONFIG_PATHS`) prints `hi world`, writes `greeting.txt`, and prints `yo world` when the caller sets `SKOGAI_HELLO_GREETING=yo`.
