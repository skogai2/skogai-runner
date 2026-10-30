# Context Summary

Persistent record of architectural decisions, discovered patterns, gotchas, and active context.
This file is referenced in CLAUDE.md and loaded every session.

## Active Context
- Current priority: establish functional composition, idempotent effects, immutable intent/events, strong types, and small Unix interfaces before expanding modules.
- The earlier plans remain active. Read `AGENTS.md`, `docs/design.md`, and `docs/plan.md`.
- Next: concrete relationship/operation contracts, then one hand-prepared local workorder with one command and one owned output. Workorder preparation, JSONL evidence, and capability enforcement are planned, not implemented.

## Cross-Cutting Concerns
- Stack: bash + argc, tests in bats, tools managed via mise (`latest`, not pinned) (argc, jq, yq, bats); Arch container (`mise run test:container`) and PKGBUILD in `packaging/arch/`
- Intended architecture: skogai-runner will provide the single entrypoint for skogai 3.0 init/setup/bootstrap/install. `src/core/` holds system-level modules (think /etc/skogai, /usr/share/skogai); `.skogai/` is userspace / local override. argc is the interface for both user and agents.
- Key constraints: lowercase single-segment names; no sed/awk in the core template; trust existing tools (pacman, git, mise) instead of reinventing.

## Domain: core runner

### Decisions
- bash + argc chosen: argc gives one declarative CLI surface (help, completion, parsing) usable by humans and agents alike (2026-10-29)
- `best-version-so-far/` contains active module plans and reusable implementation. Foundation work comes first; tasks may reuse it deliberately. `agents/` and `docs/argc*` also contain reference material. Earlier validation claims need rechecking (clarified 2026-10-29)

### Patterns
- Tests isolate HOME under `$BATS_TEST_TMPDIR` and drive the template via `argc --argc-run`.

### Gotchas
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
