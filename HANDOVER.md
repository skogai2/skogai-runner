# skogai-runner: handover

started from a skogai session, 2026-10-18 (skogai branch `bridge-cse_013WWYqpWeqHxJuZ6CaqYtLf`); rebuilt around modules 2026-10-22/23. broken out of the marketplace plugin `plugins/skogai-runner` into this standalone repo 2026-10-26; the plugin parts (SessionStart hook, `module` and `runner` skills) were dropped and can be re-added later as a thin plugin over this repo. the same day runner, memory and type moved to `.skogai/modules/`, so this repo ships core only: the start of skogai 3.0.

## intent

skogai-runner is a command runner, in the sense of argc, make, just or mise tasks. `skogai` is the one command; what it can do is whatever modules it finds. skogai 3.0 is a rework around that runner and its core module. agent io, memory and types are things a module can do, not what the runner is.

skogix's words: "you will be the one writing context, your intentions and will be the one managing yourself". the runner is the ground for that: the same commands everywhere, each one found, configured, tested and run the same way, so whoever writes a module (a person or an agent) gets the rest for free.

## what it is

`skogai` is the runner, argc the engine under it. everything it does is a module; core is the one that ships.

- `bin/skogai`: link it onto `PATH`. `skogai <name> ...` finds the module when it runs and execs its argc script with its env; anything else goes to core.
- `docs/module.md`: the spec. a module is a dir with a `module.md` (command, tools, requires, files, config defaults) and usually an argc script.
- `modules/core`: the runner's own commands.
  - `skogai config get|set|unset|list|env|files`: config across module defaults, system, global, local, `module.local.md`, `--file` and `SKOGAI_*` env.
  - `skogai module ls|show|check|add|diff|new|test|build|sandbox|env|command`: finding, checking, installing, scaffolding, testing and building modules.
  - the test base every module stands on (`tests/helper.bash`, `tests/contract.bats`), the scaffold (`templates/module/`), the build template (`templates/main.sh`) and the argc reference (`docs/argc/`).

### example modules

in `.skogai/modules/`, this repo's local layer: they run from here, are not on `SKOGAI_MODULE_PATH` and do not ship. they show what a module can be, from small to large.

- `memory`: `.skogai/memory/`, one fact per file with a `stale_after`. the small worked example: config defaults, a template, a schema.
- `type`: instance schemas. a module requiring it offers `schema/<x>.json` and globs its instances with `<module>.schema.<x>`; `skogai type check` validates their frontmatter with ajv. an example of a module holding others to a contract.
- `runner`: typed agent io, `send :: (prompt, [file], schema) -> json`, plus `improve`, `wo`, `journal`. the largest; its name is from before, and it is one use of the runner, not the runner.

## decisions

- **skogai is the runner**: no `~/Argcfile.sh` and no registry. `bin/skogai` resolves modules dynamically; `skogai module build` generates the static file a shell needs for help, completion and man pages (the old-core build trick, `ARGC_COMPLETIONS_PATH` instead of a completions repo entry).
- **modules, not scripts**: a module is the argc script plus the files it works with and its config defaults, copied into `.skogai/` as a unit. found local, then global, then sources; runs from wherever found.
- **core ships, the rest is local**: the repo is about the runner. other modules live in `.skogai/modules/` until they earn a place on `SKOGAI_MODULE_PATH`, here or elsewhere.
- **a module reads its world from env**: `SKOGAI_MODULE_DIR`, `SKOGAI_LOCAL_DIR`, `SKOGAI_<NAME>_<KEY>`. no lookups of its own; it refuses to run outside `skogai`.
- **config is git-config in layers**: later wins, `--show-origin` says which. a source module is never written to; its local overrides go in `module.local.md`.
- **core sets the test base**: every module you require runs its contract against you (core's always), then its own tests, all isolated from the caller's config.
- **pure by default**: a command that changes an existing file prints a plan and exits `1`; only `--apply` writes. scaffolds create new files and refuse to overwrite.
- **installing is an offer**: changed installed files are kept, `module diff` shows how.

the example modules add their own: runner inlines files instead of giving tools (`--tools` opts in), and takes whole files back and derives the patch with `diff -u`.

## verified

- 2026-10-26, after the move: `bin/skogai module ls` finds core as `source` and memory, runner, type as `local`. `bin/skogai module test` (bats via mise): 115 ok, 5 failing, all in `modules/core/tests/core.bats`, all assuming memory or runner are sources: 24 (`module build` lists every module), 27 and 29 (`module sandbox` installs memory, runs runner), 37 (local dir from a subdir), 39 (`module show memory`). core's tests need to make their own example module instead.
- before the move: all of `module test` green; a fresh `module new` scaffold passes the contract and its own test.
- `skogai module sandbox`: eval in bash and source in fish give a shell where every module is `local` in `/tmp/skogai/repo` and `skogai` is the sandbox build.
- the built `skogai`: help, runs, completion (including module choices like runner's schemas) through `ARGC_COMPLETIONS_PATH`, man pages.
- examples: `skogai memory ls/stale/index` read-only against `~/skogai`; `wo run` with `sandbox: true`, `tools: Bash` and `allow:` against haiku ran `skogai module ls` in its own sandbox; earlier `improve` produced a patch with 2 of 3 hunks right. **review patches, don't blind `--apply`.**

## not verified

- `skogai` from outside this checkout since the move: only core is a source, so other modules come from `~/.config/skogai/modules/`, whose copies are behind.
- `skogai` as the `claude` user, and from a shell with the build's env lines in place.
- runner `improve --apply` and `journal harvest` against a real model since the port.
