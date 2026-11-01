# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

- @.skogai/TODO.md contains one-line descriptions of tasks to be done
- !`wt step diff -- --cached > .skogai/tmp/wt-git-diff-cached` generates the file @.skogai/tmp/wt-git-diff-cached to show the users staged changes. see this as "proposed changes" or that it should actively be considered together with the users message.

Read @AGENTS.md (working principles) and `.harness/context_summary.md` (decisions, gotchas) at session start. `docs/design.md` and `docs/plan.md` hold the vision and the foundation-first sequence.

**Continuing work** goes through [.skogai/workorders/WORKORDERS.md](.skogai/workorders/WORKORDERS.md). In the lead session, check the queue there and hand out `open/` workorders to agents. If you were given a workorder, implement only that one, inside its `owns`.

## Commands

Tools come from `mise.toml` (argc, jq, yq, bats, all `latest`): `mise install`. Run checks through mise (`mise run test`, `mise exec -- bats ...`). The system `yq` may be a different program from mikefarah's yq, and then every contract test fails with `invalid-yaml`.

- `mise run test`: the whole Bats suite (`bats tests`)
- `bats tests/main.bats` or `bats tests/contract.bats`: one file
- `bats -f '<regex>' tests/main.bats`: tests whose name matches
- `mise run test:container`: the same suite in a clean Arch container via Podman (the repo is mounted read-only at `/repo`)
- `.harness/init.sh smoke_test`: `bash -n` on tracked scripts, plus `shellcheck -S error` when installed. `best-version-so-far/` and `docs/` are excluded
- `.harness/init.sh focused_test <file>` / `full_test`: the harness's single-file and full runs

Run a script directly with `argc --argc-run <script> <cmd> ...`. From a checkout, point the runner at temporary paths so nothing touches real `~/Argcfile.sh` or `~/.config/argc/commands`:

```bash
tmp="$(mktemp -d)"
export ARGC_COMMANDS="$tmp/commands" ARGC_MAIN="$tmp/Argcfile.sh" ARGC_TEMPLATE="$PWD/src/core/main.sh"
argc --argc-run "$ARGC_TEMPLATE" register <file> <name>
argc --argc-run "$ARGC_MAIN" --help
```

The README demo uses `scripts/memory.sh`, which is not in this checkout. Use any small argc script instead.

## Architecture

Everything is Bash, and argc comment tags (`# @cmd`, `# @arg`, `# @meta`, `# @env`) form the interface: they provide parsing, help, completion and JSON export (`argc --argc-export`). Each script ends with `eval "$(argc --argc-eval "$0" "$@")"`, and argc sets `argc_*` variables before the function runs.

**`src/core/main.sh`: the packaged runner.** It is a template, not the file users run. `sync` copies the template minus its final eval line, adds one generated recipe per symlink in the registry (`ARGC_COMMANDS/<name>.sh`), and puts the eval line back. It validates the result with `argc --argc-export`, then moves it over `ARGC_MAIN` in one step. Each generated recipe calls `_delegate`, which `cd`s to `ARGC_PWD` (the caller's directory, since argc runs from the Argcfile's directory) and runs `argc --argc-run` on the registered script. `_choice_delegate` sends completion to the child script's own `--argc-compgen`. Things to keep intact:
- `sync` requires the template's last line to be exactly the eval line, and tests check that the output has exactly one.
- The generated main is never edited by hand. Changes go in the template or in the registered scripts.
- Registered names become shell functions, so `_reserved` rejects runner commands, builtins and keywords. External tools are called as `command <tool>` so a registered name like `rm` cannot shadow them.
- The packaged default `ARGC_TEMPLATE=/usr/share/skogai/core/main.sh` comes from `packaging/arch/PKGBUILD`, which builds the **committed HEAD**.

**`src/core/contract/argc.sh`: the relationship contract checker (feature F001).** `check <file>...` reads Markdown+ frontmatter (the keys are `name`, `description`, `depends_on`, `reads`, `writes`, `owns`, `watches`, `defaults`) and prints one JSON verdict per file: `{file, verdict, reasons}`. Bash handles the parse stage (frontmatter → yq → JSON records). A single jq program (`VERDICTS`) applies the per-file and cross-file rules (missing-dependency, duplicate-name, ownership-conflict, write-not-owned, path-outside-scope, …). An invalid file still counts as an answer, so the exit code is 0. Exit 2 means bad arguments and exit 1 means yq or jq is missing.

**Tests.** Each test sets `HOME` and every `ARGC_*` path under `$BATS_TEST_TMPDIR` and drives scripts through `argc --argc-run`. Contract fixtures follow a naming rule: each `tests/fixtures/contract/invalid/<reason>/` directory must produce exactly the reason `<reason>`. Each multi-file case directory under `valid/` (or `invalid/`) is checked as a single call, against its `expected.jsonl` where one exists. Add a new rule by adding a fixture directory named after its reason.

**`best-version-so-far/`** is the earlier module-based design (`bin/skogai`, `modules/`, `docs/module.md`, `HANDOVER.md`). It is still active, but `bats tests` doesn't run it, and its old validation claims need rechecking before reuse. `docs/argc/` and `docs/argc-completions/` are upstream reference snapshots of unknown revision, so check the pinned links in `docs/argc-guide.md` before relying on version-sensitive argc behavior.

## Conventions specific to this repo

- Machine-readable output goes to stdout and diagnostics to stderr. Validate before any effect, and make effects idempotent.
- Names are lowercase, one segment (`^[a-z][a-z0-9-]*$`). Don't use sed or awk in the core template. Prefer existing tools (git, mise, pacman) over new machinery.
- Documentation must keep *intended*, *implemented* and *verified* behavior separate. Workorders, JSONL evidence and capability enforcement are planned and not implemented yet.

## Harness

This project uses the Long-Running Agent Harness (vv-harness plugin).

- Feature tracking: `.harness/features.json`
- Context and decisions: `.harness/context_summary.md`
- Progress handoff: `.harness/claude-progress.txt`
- Build/test: `.harness/init.sh` (bash + argc, bats via mise)
- Quality gates: `.claude/hooks/` (PreToolUse scope enforcement, git identity check, commit gate that denies staging and committing in the same command and scans staged additions for secrets; TaskCompleted quality check). `.harness/` bookkeeping files are lead-owned and protected by `enforce-scope.sh`

## Git Identity

Emil Skogsund <emil@skogsund.se>, HTTPS remote `github.com/skogai2/skogai-runner` (no SSH key).
