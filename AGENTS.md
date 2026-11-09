# skogai-runner

Get the absolute basics dependable, then build small, self-sustaining modules. The old plans are still active. We are putting their foundation in place first.

## Session start

- Read `.harness/context_summary.md` (decisions, gotchas). [The vision](docs/design.md) and [the plan](docs/plan.md) hold the foundation-first sequence.
- @.skogai/TODO.md contains one-line descriptions of tasks to be done. [TODO.md](TODO.md) and [best-version-so-far/TODO.md](best-version-so-far/TODO.md) retain the wider backlog.
- !`wt step diff -- --cached > .skogai/tmp/wt-git-diff-cached` generates the file @.skogai/tmp/wt-git-diff-cached to show the user's staged changes. Treat it as proposed changes, to be considered together with the user's message.
- Continuing work goes through [.skogai/workorders/WORKORDERS.md](.skogai/workorders/WORKORDERS.md). In the lead session, check the queue there and hand out `open/` workorders to agents. If you were given a workorder, implement only that one, inside its `owns`.

## Current state (2026-11-07)

Every module is being remade from the ground up, config first (branch `remake/config`). Config, module install, run, the contract checker (usage and argc versions), `main.sh` and `main-usage.sh` were deleted with their tests, examples and docs; their last state is commit `2913d23`. What remains is `src/core/log/usage.sh` (the read-only reader of the run event log) and its test. `packaging/arch/PKGBUILD` still installs the deleted `src/core/main.sh`.

Decisions for the config remake are in `.harness/context_summary.md` (Active Context). Config storage is undecided until the mise research in `.skogai/research/mise.md` is reviewed.

## The pieces

- **usage + mise** are the interface (skogix, 2026-11-06). Scripts declare their CLI in `#USAGE` comments and run under `usage bash`; usage provides parsing, help, completion and `effect` metadata for agents (`usage mcp`). argc was the earlier interface; it is no longer extended.
- **mise** provides the development environment, dependencies, and tasks. Modules call each other rather than receiving injected environment. Give each setting a clear owner and precedence.
- **Markdown+** makes intent and relationships programmable. A module starts as a Markdown file: prose describes intent; typed frontmatter declares dependencies, ownership, reads, writes, watches, and defaults. Add behavior as those declarations acquire precise meanings.

## Commands

Tools come from `mise.toml` (argc, usage, jq, yq, bats, all `latest`): `mise install`. Run checks through mise (`mise run test`, `mise exec -- bats ...`). The system `yq` may be a different program from mikefarah's yq.

- `mise run test`: the whole Bats suite (`bats tests`)
- `mise run test:container`: the same suite in a clean Arch container via Podman (the repo is mounted read-only at `/repo`)
- `bats tests/<file>.bats`, `bats -f '<regex>' tests/<file>.bats`: one file, or tests whose name matches
- `.harness/init.sh smoke_test`: `bash -n` on tracked scripts, plus `shellcheck -S error` when installed. `best-version-so-far/` and `docs/` are excluded
- `.harness/init.sh focused_test <file>` / `full_test`: the harness's single-file and full runs

Tests set `HOME` and every tool path under `$BATS_TEST_TMPDIR`. A test that touches mise isolates it with `env -i` plus `MISE_*` dirs under the test's tmp dir. A test that writes run events isolates `XDG_STATE_HOME` and unsets `SKOGAI_LOG`.

## How to build

- Keep it primitive and concrete. Prefer files, standard streams, exit codes, Git, and existing tools (git, mise, pacman). Add a service, socket, or bus when a demonstrated requirement needs it.
- Use small functions and tools with explicit inputs and outputs. Keep decisions separate from effects. Put machine-readable results on stdout and diagnostics on stderr.
- Names are lowercase, one segment (`^[a-z][a-z0-9-]*$`). Don't use sed or awk in core scripts.
- Make effects idempotent: repeating the same operation must not duplicate its effects. Define operation identity and retry behavior before automating retries.
- Keep accepted intent and recorded events immutable. A revision creates a linked record. Configuration and generated views may change under an explicit contract.
- Validate types and relationships before effects. Reject invalid, ambiguous, or unsupported declarations clearly. Do not silently invent defaults or treat missing input as success.
- Establish ownership before writing a file or resource. Use isolated paths and atomic replacement where appropriate. Specify partial-failure behavior for external effects that cannot be rolled back.
- Make prohibited actions unavailable through filesystem access, credentials, and exposed tools. Frontmatter and prose alone do not enforce permissions. Give the agent freedom within the capabilities prepared for its workorder.
- Preserve unrelated work. Review the diff and run checks appropriate to the change; isolate tests from real user configuration.
- Documentation keeps *intended*, *implemented* and *verified* behavior separate.

## Workorders and evidence

A workorder prepares the work: user intent, relevant context and files, typed inputs and deliverables, dependencies, capabilities, writable scope, and acceptance checks. Present its environment and tools at session start. Hand-prepare one complete example before generalizing its schema.

The target is an append-only JSONL event record connecting messages, tool use, outcomes, and file changes to the workorder. Git supplies the diff; observations and external effects need their own evidence. At a workorder, session, or PR boundary, use that evidence to explain the result and prepare a commit connecting change to intent. Commit and publish according to the task's authorization.

This lifecycle is a goal, not an implemented guarantee. Until tooling enforces it, keep a reviewable diff and a clear account of intent, changes, checks, and unresolved effects. Do not claim validation or an event trail that was not recorded.

## Continuity

`best-version-so-far/` is the earlier module-based design (`bin/skogai`, `modules/`, `HANDOVER.md`). It contains active design and reusable implementation work; it is not superseded, but `bats tests` doesn't run it. Revalidate behavior and old test claims before reuse. `docs/argc/` and `docs/argc-completions/` are upstream reference snapshots of unknown revision; check the pinned links in `docs/argc-guide.md` before relying on version-sensitive argc behavior.

Extend existing concepts before introducing another framework. When a contract is unclear, write the smallest concrete example and record the unresolved decision.

## Harness

This project uses the Long-Running Agent Harness (vv-harness plugin).

- Feature tracking: `.harness/features.json`
- Context and decisions: `.harness/context_summary.md`
- Progress handoff: `.harness/claude-progress.txt`
- Build/test: `.harness/init.sh` (bash, bats via mise)
- Quality gates: `.claude/hooks/` (PreToolUse scope enforcement, git identity check, commit gate that denies staging and committing in the same command and scans staged additions for secrets; TaskCompleted quality check). `.harness/` bookkeeping files are lead-owned and protected by `enforce-scope.sh`

## Git identity

Emil Skogsund <emil@skogsund.se>, HTTPS remote `github.com/skogai2/skogai-runner`.

<!-- trail:start -->
## Trail — repo context graph

This repo is indexed in `.trail/cache/`: small linked markdown nodes that explain each
system and carry exact file:line spans, kept in sync with the code through git.

For ANY task here — understanding how something works, finding where code lives,
or scoping a change — get context from the graph before grepping or opening
source files. Re-ask freely (it's cheap) and reuse literal identifiers you
already have (symbol, error string, file name) as the query. New to this repo?
Run `trail map` first — a token-budgeted orientation (dir clusters, hubs,
hotspots), no LLM, no key.

- Run `trail ask "<your question>" --source` → ranked nodes with the relevant
  code spans inlined (each hit's ≤8-line crux by default; `--full` for whole
  definitions when the crux isn't enough). Match the tool to the task shape:
  for understanding or editing, the top node IS the answer — cite its
  `covers:` file:line spans and edit straight from `--source`. For
  exhaustive tasks ("every occurrence / every caller of this pattern"), ranked
  results are top-N, not complete — run `trail grep "<literal>"` instead
  (exhaustive over indexed files, grouped by enclosing symbol), falling back
  to raw `grep -rn` only for unindexed files.
- `trail skeleton <file>` → every definition's signature + span, ~10× cheaper
  than reading the file; use it to skim an API surface.
- `trail callers <symbol>` gives precomputed, exact edges — who calls this.
  Add `--direction out` for what it calls, or `--depth N` to walk
  transitively for the full blast radius. For structural questions, skip
  ranking and use this directly.
- Or browse: `.trail/cache/INDEX.md` lists every node; follow the links.
- Monorepos and folders of multiple repos rank fairly across sub-projects —
  hits carry `[scope/]` labels naming which one they're from. Narrow with
  `trail ask "<task>" --in <scope>/` once you know where you're working.

If a returned span is truncated ("+N more lines"), open the file at that exact
range before finalizing. Only open source files when a node genuinely lacks a
needed detail, and then at the exact file:line the node points to — never
re-read whole files.

After big code changes, refresh the graph with `trail build` (deterministic,
no API key, $0).
<!-- trail:end -->
