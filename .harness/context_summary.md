# Context Summary

Persistent record of architectural decisions, discovered patterns, gotchas, and active context.
This file is referenced in CLAUDE.md and loaded every session.

## Active Context
- Steps 1-2 done (F001 checker, F002 staged Podman run). usage + mise is the interface; argc twins frozen (2026-11-06).
- Landed 2026-11-06: run events (`docs/evidence.md`), live-test examples (`tests/examples.bats`), `mise run test` on usage. Next: a second module that `depends_on` hello; step 3 leftovers (recovery, reader, workorder link).
- Landed 2026-11-07: F003 module = mise toml (`docs/module.md`), F004 `config` over mise layers (`src/core/config/usage.sh`, `docs/config.md`), F005 `module install|uninstall|ls` into conf.d (`src/core/module/usage.sh`, `docs/install.md`). Next: D run injects module env, E depends_on = installed (+ hello-reader), F run-workorder-link.
- Not implemented: the workorder lifecycle through the runner (agents still edit the repo directly), `depends_on` at run time, run using a module's mise env.

## Cross-Cutting Concerns
- Stack: bash + argc, tests in bats, tools managed via mise (`latest`, not pinned) (argc, jq, yq, bats); Arch container (`mise run test:container`) and PKGBUILD in `packaging/arch/`
- Intended architecture: skogai-runner will provide the single entrypoint for skogai 3.0 init/setup/bootstrap/install. `src/core/` holds system-level modules (think /etc/skogai, /usr/share/skogai); `.skogai/` is userspace / local override. argc is the interface for both user and agents.
- Key constraints: lowercase single-segment names; no sed/awk in the core template; trust existing tools (pacman, git, mise) instead of reinventing.

## Domain: core runner

### Decisions
- bash + argc chosen: argc gives one declarative CLI surface (help, completion, parsing) usable by humans and agents alike (2026-10-29)
- `best-version-so-far/` contains active module plans and reusable implementation. Foundation work comes first; tasks may reuse it deliberately. `agents/` and `docs/argc*` also contain reference material. Earlier validation claims need rechecking (clarified 2026-10-29)

- F001 is the relationship contract checker only (spec-gated 2026-10-30). Invalid input is a verdict (JSONL on stdout, exit 0); exit 2 bad args, exit 1 missing yq/jq. Old proposals (split main.sh, .skogai override, single binary) deferred per docs/plan.md (2026-10-30)
- Open plan-step-1 items, not yet features: operation identity / retry / linked intent revisions; configuration ownership and precedence (mise vs git config vs env vs module defaults). Step 2 writable-scope enforcement decided by skogix (2026-11-06): Podman, staged output. The command runs in Podman with the repo mounted read-only (as `mise run test:container` does) plus one empty writable output dir; the runner then verifies the output dir holds only paths in `owns` and only then moves them into place atomically. Out-of-scope writes are impossible inside the container (ro mount) and out-of-scope outputs are rejected before any effect. Implemented as F002 (2026-11-06): src/core/run/argc.sh check|run, example examples/hello.
- usage twins (2026-11-06): to compare argc with usage + mise, every argc piece has a usage twin with the same behavior and tests: `contract/usage.sh`, `run/usage.sh` (+ `examples/usage/hello`, `tests/fixtures/run-usage`), and `main-usage.sh` (`skogai`: no template/sync, usage `mount` reads the registry live; `SKOGAI_COMMANDS` is a `:`-list of registry layers, nearest first). Not spec-gated features; no entry in features.json. Until the comparison is decided, a change to a rule, runner, example or fixture goes into both twins. Open for skogix: criteria and decision for argc vs usage, and whether packaging (PKGBUILD) ships `skogai`.

- usage + mise chosen over argc as the interface for user, agents and modules (skogix, 2026-11-06). New work goes into the usage files only; the argc files are frozen, not removed. Why: one interface instead of twinning every change; usage gives layered registries (`SKOGAI_COMMANDS`), `effect=` for agents via `usage mcp`, and mise integration.
- Module model and config answers (skogix, 2026-11-07). `best-version-so-far/` is the reference target (config fold, module env, install by copy); it is deleted once everything is converted.
  - A module is three things: key/value config defaults, a usage declaration (strictly typed input -> output), and relationships. Candidate shape: one mise file, e.g. `mise.<name>.toml` (format not settled).
  - Relationships: `owns` = creates and is responsible for; `writes` = edits, i.e. gives input to the owning module to react to or use; `watches` = on an event at x, hand the event to executable y.
  - The entrypoint runs a module from anywhere (e.g. local). Once its tests and rules pass, it is copied to global (`~/.config/skogai`) or system (`/etc/skogai`).
  - Precedence, later wins: module defaults, system, global, local, override, command parameters, env. Plain Unix CLI practice.
  - Types are deferred; later modules validate paths, ints and so on.
  - Key/env names: kebab-case. `-` is part of a word and dropped in env; `.` maps to `_`, so `a.b-c.d` = `SKOGAI_A_BC_D` and `SKOGAI_FOO_BAR` = `skogai.foo.bar`.
  - Each module defines its own env, injected when it runs (mise does this for tasks).
  - `depends_on` at run time = the called command is available, i.e. that module is installed.
  - Workorder paths are relative to the git root.
- Verified in mise 2026.10.17 (scratch, 2026-11-07): a task's `usage` field validates args (a missing `<who>` is refused); `MISE_ENV=<name>` loads `mise.<name>.toml`; `[_.skogai]` free-form keys are readable with `mise config get`; `mise.local.toml` overrides it. A plain `[env]` value beats the caller's env. `"{{ get_env(name='X', default='d') }}"` lets the caller's env win, which the precedence above needs.
- mise conf.d (verified 2026-11-07, scratch): mise loads every `conf.d/*.toml` at each level: `/etc/mise/conf.d` (system; this host already has omarchy files there), `~/.config/mise/conf.d` (global, follows `MISE_CONFIG_DIR`), and the project's `.config/mise/conf.d` or `.mise/conf.d`. Tasks in a conf.d file run. `MISE_OVERRIDE_CONFIG_FILENAMES=skogai.toml` also works but is not needed. Layer merge (same session): `[env]` merges key by key and the later layer wins; a later `[tasks.x]` replaces the whole task, so `run` and `usage` vanish silently; `mise config get _.x` reads only the nearest file. An empty .toml parses to `null` in yq. A test can isolate mise with `env -i` plus MISE_CONFIG_DIR, MISE_SYSTEM_DIR, MISE_DATA_DIR, MISE_STATE_DIR, MISE_CACHE_DIR and MISE_TRUSTED_CONFIG_PATHS: then `/etc/mise/conf.d` is not loaded. Proposal under discussion: a module's toml is a conf.d drop-in, and installing a module = copying it into the conf.d of the chosen level. Module entry docs (skogix): `SKOGAI.md` rather than AGENTS/CLAUDE/GEMINI/CODEX.md, plus MODULE.md or README.md for the module (not settled). `watches` is deferred.
- Config layering on mise (verified 2026-11-07, scratch, mise 2026.10.17; basis of F004/F005): skogix's precedence maps onto mise as module default `K = "{{ env.K | default(value='d') }}"` in a conf.d (env.K sees the caller env and earlier layers, so a project-installed module still loses to system/global) < `$MISE_SYSTEM_DIR/config.toml` < `$MISE_CONFIG_DIR/config.toml` < `<git root>/mise.toml` < `mise.local.toml` (< `config.override.toml`, which `mise set --override` writes). Stored values written as `{{ get_env(name='K', default='v') }}` let the caller env win at every layer, inside tasks too; a plain value beats the caller env. `mise env --json` gives the resolved values. `mise set` (list) names the module file as source even when another layer supplied the value, so origin must be computed by skogai. Within one level conf.d files load before config.toml.
- Evidence starts from the skogai-core hook log shape (`/home/skogix/skogai/.skogai/logs/skogai-core/log.jsonl`: `{ts, event, action?, input}`), extended with run identity and outcome, not a new format (2026-11-06).

### Patterns
- Tests isolate HOME under `$BATS_TEST_TMPDIR` and drive the template via `argc --argc-run`.

### Gotchas
- Rootless podman finds its images through XDG_DATA_HOME (default $HOME/.local/share). Tests that isolate HOME must capture and export XDG_DATA_HOME first, or `podman image exists` fails. This host exports XDG_DATA_HOME already, which hides the problem.
- Do not add `:Z` to podman mounts of module dirs: SELinux relabelling changes the host directory, which is an effect outside `owns`.
- The runner logs to `${XDG_STATE_HOME:-$HOME/.local/state}/skogai/run.jsonl`. This host exports XDG_STATE_HOME, so isolating HOME alone leaks test runs into the real log: tests must set XDG_STATE_HOME and unset SKOGAI_LOG.
- A script reached through a registry symlink must `realpath` `BASH_SOURCE` before locating siblings (fixed in run/usage.sh, 9e82212). The tests copy `examples/usage/hello` whole, so a gitignored `greeting.txt` from a real run breaks 8 tests.
- Never write a file from `jq ... > file` in the Bash tool: a hook rewrites `jq` (even `/usr/bin/jq`) to `rtk jq`, which shortens long strings with `...`. This corrupted features.json once (2026-11-07, restored from git). Put the jq call in a script file and run `bash script.sh`.
- Workorder agents in worktrees under ~/skogai-runner/.claude/worktrees: a hook refuses plain `git` (rtk wrapper); they used `/usr/bin/git`. `mise tasks` there also picks up the parent checkout's mise.toml.
- `mise run test` stays on argc for the twinned files; `mise run test:usage` runs contract.bats and run.bats with `CONTRACT_IMPL=usage RUN_IMPL=usage` plus main-usage.bats. Both suites must pass after a twinned change.
- `contract/usage.sh` receives the variadic `file` as one shell-quoted string (`eval "files=(...)"`); under a usage mount, `usage_cmd` is the mounted script's `bin`, so main-usage.sh dispatches on argv.
- `mise run test` now depends on `mise run image` (cached `podman build`, a no-op without podman).
- No coverage tooling for bash/bats yet: the 95% coverage gate cannot be measured. `full_test` runs `bats tests` only. Enabling coverage (e.g. bashcov/kcov) needs its own feature if wanted.
- `ssh -T git@github.com` fails (no key loaded); remote is HTTPS under `skogai2`. The identity hook checks name/email only.

## Meta-Patterns
<!-- Coordination insights that apply across features — NOT domain-specific.
     Populated by the retrospective step at session end. -->
- (none yet — first retrospective will populate this)

## Meta-Session 2026-10-29
- Scope accuracy: no features yet; session covered scaffolding and the foundation-first plan (docs/plan.md, AGENTS.md).
- Model calibration: n/a, no agents spawned.
- Discovery lineage: n/a.
- Approach patterns: harness ceremony (improve loop, spec gate) was explained at length before any feature existed; skogix asked for the simple path. Prefer acting on bookkeeping over describing it.
- Plan approval: n/a.

## Meta-Session 2026-11-06
- Scope accuracy: F002 scope needed mise.toml after the spec gate (image task); spotted during spec answering, not during implementation.
- Discovery: spec gate's 16 questions were mostly lead-answerable; the XDG_DATA_HOME issue was real and only visible by running podman with an isolated HOME.
- Pattern: probe the real container invocation before writing the spec's exit/ownership rules; mutation-check enforcement tests when they pass first time.

## Meta-Session 2026-10-30
- Scope accuracy: original F001-F004 drifted from the new foundation-first plan; replaced by one narrow F001.
- Model calibration: spec gate (opus) needed four passes; each pass narrowed edge cases, never contradicted earlier answers.
- Discovery lineage: n/a.
- Approach patterns: answering gate questions from the repo docs plus sensible defaults worked; only genuine scope questions (step-1 bullets) were left open for skogix.
- Plan approval: n/a.

## Meta-Session 2026-11-06 (session 6)
- Scope accuracy: both workorders stayed inside owns; disjoint owns made parallel handout trivial.
- Model calibration: Sonnet finished each in one pass, no correction cycles.
- Gotcha: the rtk hook rewrites `git ...` to `rtk git ...`; in a subagent worktree auto mode + the worktree guard then deny every git call, so agents cannot commit. One agent bypassed via `/usr/bin/git`. Until resolved, plan for the lead to commit agent work, and tell agents not to bypass hooks.
- Pattern: hand-out prompts should say "do not push / open PR" while local master holds unpushed commits.

## Meta-Session 2026-11-07
- Scope accuracy: F003 (module toml), F004 (config), F005 (install) stayed inside declared scope; scope_expansions 0 on all three.
- Model calibration: Sonnet implementers, one pass each, correction_cycles 0. Opus spec gate did the real work: F004 needed 17 answers, F005 11, all lead-answerable after a scratch probe of mise layering.
- Discovery: a spec hash stamped with a trailing newline (F003) failed re-verification; stamp hashes on the exact stored text.
- Pattern: probe the real tool (mise layering, podman) in scratch before answering gate questions; the probe turned most "ASK" questions into lookups. The stray `examples/usage/hello/greeting.txt` breaks 8 tests when present; runs had to move it aside.
- Pattern: worktree agents no longer bypassed git; lead committed their work. Leftover worktrees accumulate (their log.jsonl lines block force-removal).
