# Context Summary

Persistent record of architectural decisions, discovered patterns, gotchas, and active context.
This file is referenced in CLAUDE.md and loaded every session.

## Active Context
- Currently working on: project initialization (very early; expect pruning and restructuring soon)
- Next up: first feature implementation

## Cross-Cutting Concerns
- Stack: bash + argc, tests in bats, tools pinned via mise (argc, jq, yq, bats); Arch container (`mise run test:container`) and PKGBUILD in `packaging/arch/`
- Architecture: skogai-runner builds the single entrypoint for skogai 3.0 init/setup/bootstrap/install. `src/core/` holds system-level modules (think /etc/skogai, /usr/share/skogai); `.skogai/` is userspace / local override. argc is the interface for both user and agents.
- Key constraints: lowercase single-segment names; no sed/awk in the core template; trust existing tools (pacman, git, mise) instead of reinventing.

## Domain: core runner

### Decisions
- bash + argc chosen: argc gives one declarative CLI surface (help, completion, parsing) usable by humans and agents alike (2026-10-29)
- `best-version-so-far/`, `agents/`, `docs/argc*` are harvest/reference material, outside feature scope unless a feature names them (2026-10-29)

### Patterns
- Tests isolate HOME under `$BATS_TEST_TMPDIR` and drive the template via `argc --argc-run`.

### Gotchas
- No coverage tooling for bash/bats yet: the 95% coverage gate cannot be measured. `full_test` runs `bats tests` only. Enabling coverage (e.g. bashcov/kcov) needs its own feature if wanted.
- `ssh -T git@github.com` fails (no key loaded); remote is HTTPS under `skogai2`. The identity hook checks name/email only.

## Meta-Patterns
<!-- Coordination insights that apply across features — NOT domain-specific.
     Populated by the retrospective step at session end. -->
- (none yet — first retrospective will populate this)
