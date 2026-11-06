# Current runner

The implementation in [src/core/main.sh](../src/core/main.sh) turns a registry of argc scripts into one generated main script. Bash functions hold the behavior; argc reads comment tags to provide the command interface.

## Paths

| Variable | Default | Purpose |
| --- | --- | --- |
| `ARGC_COMMANDS` | `${XDG_CONFIG_HOME:-$HOME/.config}/argc/commands` | Registry of `<name>.sh` symlinks |
| `ARGC_MAIN` | `$HOME/Argcfile.sh` | Generated main script, replaced by sync |
| `ARGC_TEMPLATE` | `/usr/share/skogai/core/main.sh` | Template used to generate the main script |

From a checkout, set `ARGC_TEMPLATE` to the absolute path of `src/core/main.sh`. The script's default points to the packaged installation.

## Register and generate

`register <file> <name>` resolves the file relative to the caller's directory, validates it with `argc --argc-export`, creates or repoints a registry symlink, then runs `sync`. Names must match `^[a-z][a-z0-9-]*$`. Runner command names, Bash builtins, and keywords are reserved.

`sync` reads the template and appends one recipe per usable registry entry, followed by the argc eval line. Each recipe's description comes from the first line of the registered script's description. Missing or unparsable entries are skipped with warnings. The generated script is validated before being moved over `ARGC_MAIN`.

Keep custom commands in registered source scripts. Edits to the generated main are lost on the next sync. `unregister <name>` removes the registry entry and regenerates the main; it leaves the source script in place. `ls` lists registrations and marks missing targets.

## Execute and complete

A generated recipe forwards arguments to `argc --argc-run <registered-script> ...`. The delegate changes back to `ARGC_PWD` when available, preserving the original caller's working directory even though argc runs its Argcfile from the file's directory. Forwarded arguments are declared with `args~`, allowing the child script to interpret its own options.

Completion calls `argc --argc-compgen generic` on the registered script with the forwarded words. The adapter preserves completion control lines, lowercases path value controls, and strips candidate color fields before handing candidates to the outer completion engine. A leading `?` on the choice declaration makes this completion advisory rather than validation of forwarded arguments.

Inspect candidates without installing shell configuration:

```bash
argc --argc-compgen generic "$ARGC_MAIN" argc memory ''
```

Shell integration is a separate step. See the [upstream completion guide](https://github.com/sigoden/argc/blob/dd0bcb484d3217c7998b717fde02e38035e67a1e/docs/compgen.md) and verify behavior against the installed argc version.

## The usage twin

[src/core/main-usage.sh](../src/core/main-usage.sh) is the same registry runner built on usage instead of argc, invoked as `skogai`. It exists to compare the two; packaging still installs only `main.sh`.

| Variable | Default | Purpose |
| --- | --- | --- |
| `SKOGAI_COMMANDS` | `${XDG_CONFIG_HOME:-$HOME/.config}/skogai/commands` | `:`-separated registry layers of `<name>.sh` symlinks, nearest first |
| `SKOGAI_MAIN` | `skogai` | The runner the mount calls back into |

- There is no template, `sync`, or generated main. `register <file> <name>` checks the script with `usage lint` and links it into the first layer; `unregister` removes it from the first layer only.
- The top-level `mount` runs `skogai _mount` whenever usage needs the command list, so a registration shows up immediately in help and completion.
- The first layer that has a name wins, and `ls` merges all layers. A project can put its own layer first through mise `[env]`.
- Names do not become shell functions, so only `register`, `unregister`, `ls` and `help` are reserved.

Verified by [tests/main-usage.bats](../tests/main-usage.bats), which `mise run test` and `mise run test:usage` both run. The contract checker and the staged runner have usage twins too (`src/core/contract/usage.sh`, `src/core/run/usage.sh`), checked by the same `contract.bats` and `run.bats` under `mise run test:usage`.

## Completion for the usage twin

[src/core/main-usage.sh](../src/core/main-usage.sh) (invoked as `skogai`) completes through usage itself. Usage's generated shell script is a shim: on each Tab it runs `usage complete-word` against the runner's spec. Registered commands reach that spec through the `mount`, which calls `skogai _mount` at completion time. Install the completion once; `register` and `unregister` never require a regeneration.

```bash
usage generate completion fish skogai -f "$(readlink -f "$(command -v skogai)")" --install
```

Replace `fish` with `bash`, `zsh`, `nu`, or `powershell` as needed. `--install` writes only the completion file. For zsh, add the `fpath+=` line that it prints to your shell configuration yourself.

- Pass `-f` with the real path of `main-usage.sh`, because the script does not print its own spec. If the checkout moves, generate the completion again.
- Do not pass `--cache-key`, because a cached spec would freeze the registry list.
- The mount runs `${SKOGAI_MAIN:-skogai}` and reads `SKOGAI_COMMANDS` from the shell's environment. A project layer exported by mise `[env]` therefore appears when you complete inside that project.

To inspect candidates without installing anything:

```bash
usage complete-word --shell fish -f "$(readlink -f "$(command -v skogai)")" -- skogai ''
```

Verified manually with usage 7.0.2 on 2026-11-06. `skogai ''` listed the registered `hello` next to `ls`, `register`, and `unregister`, and `skogai hello --` offered `--out` from hello's own spec. No automated test covers completion, and `--install` was not run as part of this check.

## Boundaries

The current runner does not discover module manifests, resolve layered skogai configuration, or build a native executable. Those concepts remain active plans, with reusable implementation work under `best-version-so-far/`. The foundation comes first; see [the plan](plan.md). `argc --argc-build` produces a standalone Bash script; it does not turn delegated scripts or their external tools into a self-contained binary.

`skogai-bridge-caller.sh` preserves the earlier bridge demo. Its `call` command expects a separately running HTTP tool bridge, and its demonstration scripts are not a full MCP service. The [demo agent README](../agents/demo/README.md) describes an earlier integration whose referenced bridge configuration and generated files are absent from this checkout.

The argc runner's test suite is [tests/main.bats](../tests/main.bats). It uses temporary home, registry, and working directories to check generation, registration, delegation, completion, and failure paths.
