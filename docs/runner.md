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

## Boundaries

The current runner does not discover module manifests, resolve layered skogai configuration, or build a native executable. Those concepts appear in earlier work and future intentions. `argc --argc-build` produces a standalone Bash script; it does not turn delegated scripts or their external tools into a self-contained binary.

`skogai-bridge-caller.sh` preserves the earlier bridge demo. Its `call` command expects a separately running HTTP tool bridge, and its demonstration scripts are not a full MCP service. The [demo agent README](../agents/demo/README.md) describes an earlier integration whose referenced bridge configuration and generated files are absent from this checkout.

The current test suite is [tests/main.bats](../tests/main.bats). It uses temporary home, registry, and working directories to check generation, registration, delegation, completion, and failure paths.
