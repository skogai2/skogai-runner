# skogai-runner

A Bash command runner built on [argc](https://github.com/sigoden/argc). Register an argc script once, then run it as `argc <name> ...`, with its own help, argument parsing, and completion.

The current implementation is [src/core/main.sh](src/core/main.sh). It generates a main `Argcfile.sh` from a directory of registered scripts. The module work in [best-version-so-far/](best-version-so-far/HANDOVER.md) remains active. We are establishing the basic contracts first, then building out that design. The current Arch package installs the registry runner template.

## Try it from the checkout

Install the tools listed in [mise.toml](mise.toml), then use a temporary registry and main file:

```bash
mise install
demo_dir="$(mktemp -d)"
export ARGC_COMMANDS="$demo_dir/commands"
export ARGC_MAIN="$demo_dir/Argcfile.sh"
export ARGC_TEMPLATE="$PWD/src/core/main.sh"

argc --argc-run "$ARGC_TEMPLATE" register "$PWD/scripts/memory.sh" memory
argc --argc-run "$ARGC_MAIN" --help
argc --argc-run "$ARGC_MAIN" memory show --slug always-commit
argc --argc-run "$ARGC_MAIN" ls
```

The demo memory script prints an action; it does not implement persistent memory. These overrides keep the generated runner outside your normal home configuration. Use a fresh shell afterward to return to the defaults.

## Install on Arch

```bash
cd packaging/arch
makepkg -si
argc --argc-run /usr/share/skogai/core/main.sh sync
```

The package builds the repository's **committed HEAD**, not uncommitted changes. It installs the template at `/usr/share/skogai/core/main.sh`; the user runs `sync` to generate `~/Argcfile.sh`. Sync replaces the target main file, so use `ARGC_MAIN` if that path already holds recipes you want to keep.

With the generated main in place, register scripts using `argc register <file> <name>`, inspect them with `argc ls`, and remove registrations with `argc unregister <name>`. Run `argc sync` after a template update or after changing a script's top-level description.

argc searches for an Argcfile in the current directory and its parents. A nearer project Argcfile takes precedence over the home runner; use `argc --argc-run ~/Argcfile.sh ...` to select it explicitly.

## Documentation and checks

- [Documentation index](docs/README.md)
- [Current runner: registry, generation, and delegation](docs/runner.md)
- [argc and argc-completions: reference map](docs/argc-guide.md)
- [Vision and foundational guarantees](docs/design.md)
- [Foundation-first plan](docs/plan.md)
- [Agent working instructions](AGENTS.md)

Run `mise run test` for the current runner's Bats suite. `mise run test:container` builds an Arch container and runs the same suite through Podman. The older module tests under `best-version-so-far/` belong to that implementation and are not included in `bats tests`.
